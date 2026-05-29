import 'dart:math';
import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/financing/domain/models/financing.dart';
import 'package:bestfin/features/financing/domain/models/financing_installment.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

abstract class FinancingRepository {
  Stream<List<Financing>> watchAllFinancings();
  Stream<Financing> watchFinancingById(String id);
  Stream<List<FinancingInstallment>> watchInstallmentsForFinancing(
    String financingId,
  );
  Future<void> createFinancing({
    required String name,
    required int totalAmount,
    required double interestRate,
    required int totalInstallments,
    required String amortizationSystem,
    required DateTime firstDueDate,
    String? linkedAccountId,
  });
  Future<void> payInstallment(String installmentId, bool isPaid);
  Future<void> deleteFinancing(String id);
}

class FinancingRepositoryImpl implements FinancingRepository {
  final db.AppDatabase _database;

  FinancingRepositoryImpl(this._database);

  @override
  Stream<List<Financing>> watchAllFinancings() {
    return _database.financingsDao.watchAllFinancings().map((list) {
      return list.map((item) => Financing.fromDb(item)).toList();
    });
  }

  @override
  Stream<Financing> watchFinancingById(String id) {
    return _database.financingsDao.watchAllFinancings().map((list) {
      final matches = list.where((f) => f.id == id);
      if (matches.isEmpty) {
        throw Exception('Financing not found');
      }
      return Financing.fromDb(matches.first);
    });
  }

  @override
  Stream<List<FinancingInstallment>> watchInstallmentsForFinancing(
    String financingId,
  ) {
    return _database.financingsDao
        .watchInstallmentsForFinancing(financingId)
        .map((list) {
          return list.map((item) => FinancingInstallment.fromDb(item)).toList();
        });
  }

  @override
  Future<void> createFinancing({
    required String name,
    required int totalAmount,
    required double interestRate,
    required int totalInstallments,
    required String amortizationSystem,
    required DateTime firstDueDate,
    String? linkedAccountId,
  }) async {
    final financingId = const Uuid().v4();

    await _database.transaction(() async {
      // 1. Insert financing header
      await _database.financingsDao.insertFinancing(
        db.FinancingsCompanion.insert(
          id: financingId,
          name: name,
          totalAmount: totalAmount,
          outstandingBalance: totalAmount,
          interestRate: interestRate,
          totalInstallments: totalInstallments,
          amortizationSystem: amortizationSystem.toLowerCase(),
        ),
      );

      // 2. Generate and insert installments
      final companions = _generateAmortizationInstallments(
        financingId: financingId,
        totalAmount: totalAmount,
        interestRatePercent: interestRate,
        totalInstallments: totalInstallments,
        system: amortizationSystem,
        firstDueDate: firstDueDate,
      );

      await _database.financingsDao.insertInstallments(companions);
    });
  }

  @override
  Future<void> payInstallment(String installmentId, bool isPaid) async {
    await _database.transaction(() async {
      // Find the installment
      final currentInstallment = await (_database.select(
        _database.financingInstallments,
      )..where((t) => t.id.equals(installmentId))).getSingle();

      final updatedPaidDate = isPaid ? DateTime.now() : null;

      // Update installment payment status
      await (_database.update(
        _database.financingInstallments,
      )..where((t) => t.id.equals(installmentId))).write(
        db.FinancingInstallmentsCompanion(paidDate: Value(updatedPaidDate)),
      );

      // Recalculate outstanding balance of financing
      final financingId = currentInstallment.financingId;
      final financing = await _database.financingsDao.getFinancingById(
        financingId,
      );
      final allInstallments = await _database.financingsDao
          .getInstallmentsForFinancing(financingId);

      // Calculate paid amortization (excluding current installment in transition, matching state)
      int paidAmortization = 0;
      for (final inst in allInstallments) {
        final wasPaid = inst.id == installmentId
            ? isPaid
            : inst.paidDate != null;
        if (wasPaid) {
          paidAmortization += inst.amortizationValue;
        }
      }

      final newOutstandingBalance = max(
        0,
        financing.totalAmount - paidAmortization,
      );

      await _database.financingsDao.updateFinancing(
        db.FinancingsCompanion(
          id: Value(financing.id),
          name: Value(financing.name),
          totalAmount: Value(financing.totalAmount),
          outstandingBalance: Value(newOutstandingBalance),
          interestRate: Value(financing.interestRate),
          totalInstallments: Value(financing.totalInstallments),
          amortizationSystem: Value(financing.amortizationSystem),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  @override
  Future<void> deleteFinancing(String id) async {
    await _database.transaction(() async {
      // Delete installments first (drift table is set to cascade, but cleaning manually is safe)
      await _database.financingsDao.deleteInstallmentsForFinancing(id);
      await _database.financingsDao.deleteFinancing(id);
    });
  }

  // Private helper to calculate SAC and Price tables
  List<db.FinancingInstallmentsCompanion> _generateAmortizationInstallments({
    required String financingId,
    required int totalAmount,
    required double interestRatePercent,
    required int totalInstallments,
    required String system,
    required DateTime firstDueDate,
  }) {
    final List<db.FinancingInstallmentsCompanion> list = [];
    final double r = interestRatePercent / 100.0;
    int outstandingBalance = totalAmount;

    if (system.toLowerCase() == 'sac') {
      final int amortizationPerMonth = (totalAmount / totalInstallments)
          .round();

      for (int i = 1; i <= totalInstallments; i++) {
        final int interest = (outstandingBalance * r).round();
        int amortization = amortizationPerMonth;

        if (i == totalInstallments) {
          amortization = outstandingBalance;
        }

        final int total = amortization + interest;
        final int remaining = max(0, outstandingBalance - amortization);

        final DateTime dueDate = DateTime(
          firstDueDate.year,
          firstDueDate.month + (i - 1),
          firstDueDate.day,
        );

        list.add(
          db.FinancingInstallmentsCompanion.insert(
            id: const Uuid().v4(),
            financingId: financingId,
            number: i,
            amortizationValue: amortization,
            interestValue: interest,
            totalValue: total,
            remainingBalance: remaining,
            dueDate: dueDate,
          ),
        );

        outstandingBalance = remaining;
      }
    } else {
      // Price
      final double pmtDouble = r == 0
          ? (totalAmount / totalInstallments)
          : totalAmount *
                (r * pow(1 + r, totalInstallments)) /
                (pow(1 + r, totalInstallments) - 1);
      final int pmt = pmtDouble.round();

      for (int i = 1; i <= totalInstallments; i++) {
        final int interest = (outstandingBalance * r).round();
        int amortization = pmt - interest;

        if (i == totalInstallments) {
          amortization = outstandingBalance;
        }

        final int total = amortization + interest;
        final int remaining = max(0, outstandingBalance - amortization);

        final DateTime dueDate = DateTime(
          firstDueDate.year,
          firstDueDate.month + (i - 1),
          firstDueDate.day,
        );

        list.add(
          db.FinancingInstallmentsCompanion.insert(
            id: const Uuid().v4(),
            financingId: financingId,
            number: i,
            amortizationValue: amortization,
            interestValue: interest,
            totalValue: total,
            remainingBalance: remaining,
            dueDate: dueDate,
          ),
        );

        outstandingBalance = remaining;
      }
    }

    return list;
  }
}
