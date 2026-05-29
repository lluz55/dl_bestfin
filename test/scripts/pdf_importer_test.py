import unittest
import sys
import os
from unittest.mock import patch, MagicMock

# Add scripts directory to path to import pdf_importer
sys.path.append(os.path.join(os.path.dirname(__file__), '../../scripts'))
from pdf_importer import NubankCardParser, NubankReceiptParser, BancoDoBrasilReceiptParser, Transaction

class TestNubankCardParser(unittest.TestCase):
    def setUp(self):
        self.parser = NubankCardParser()

    def test_can_handle(self):
        self.assertTrue(self.parser.can_handle("Fatura do cartão Nubank"))
        self.assertFalse(self.parser.can_handle("Comprovante de PIX Nubank"))
        self.assertFalse(self.parser.can_handle("Banco do Brasil Fatura"))

    @patch('pdfplumber.open')
    def test_parse(self, mock_pdfplumber_open):
        mock_pdf = MagicMock()
        mock_page = MagicMock()
        mock_page.extract_text.return_value = "05 MAI  IFOOD  R$ 45,90\n10 MAI  UBER  R$ 15,00"
        mock_pdf.pages = [mock_page]
        mock_pdfplumber_open.return_value.__enter__.return_value = mock_pdf

        transactions = self.parser.parse("fake_path.pdf")
        
        self.assertEqual(len(transactions), 2)
        self.assertEqual(transactions[0].date, "05 MAI")
        self.assertEqual(transactions[0].description, "IFOOD")
        self.assertEqual(transactions[0].amount_cents, 4590)
        self.assertEqual(transactions[0].type, "expense")

class TestNubankReceiptParser(unittest.TestCase):
    def setUp(self):
        self.parser = NubankReceiptParser()

    def test_can_handle(self):
        self.assertTrue(self.parser.can_handle("Comprovante de PIX Nubank"))
        self.assertTrue(self.parser.can_handle("Nubank Comprovante"))
        self.assertFalse(self.parser.can_handle("Fatura do cartão Nubank"))

    @patch('pdfplumber.open')
    def test_parse_expense(self, mock_pdfplumber_open):
        mock_pdf = MagicMock()
        mock_page = MagicMock()
        mock_page.extract_text.return_value = "Comprovante PIX Nubank\nData: 15/06/2026\nValor: R$ 150,00"
        mock_pdf.pages = [mock_page]
        mock_pdfplumber_open.return_value.__enter__.return_value = mock_pdf

        transactions = self.parser.parse("fake_path.pdf")
        
        self.assertEqual(len(transactions), 1)
        self.assertEqual(transactions[0].date, "15/06/2026")
        self.assertEqual(transactions[0].amount_cents, 15000)
        self.assertEqual(transactions[0].type, "expense")

    @patch('pdfplumber.open')
    def test_parse_income(self, mock_pdfplumber_open):
        mock_pdf = MagicMock()
        mock_page = MagicMock()
        mock_page.extract_text.return_value = "Comprovante PIX Nubank\nRecebido de Fulano\nData: 20/06/2026\nValor: R$ 500,00"
        mock_pdf.pages = [mock_page]
        mock_pdfplumber_open.return_value.__enter__.return_value = mock_pdf

        transactions = self.parser.parse("fake_path.pdf")
        
        self.assertEqual(len(transactions), 1)
        self.assertEqual(transactions[0].date, "20/06/2026")
        self.assertEqual(transactions[0].amount_cents, 50000)
        self.assertEqual(transactions[0].type, "income")

class TestBancoDoBrasilReceiptParser(unittest.TestCase):
    def setUp(self):
        self.parser = BancoDoBrasilReceiptParser()

    def test_can_handle(self):
        self.assertTrue(self.parser.can_handle("BANCO DO BRASIL - COMPROVANTE DE TRANSFERENCIA"))
        self.assertFalse(self.parser.can_handle("Nubank Comprovante"))

    @patch('pdfplumber.open')
    def test_parse(self, mock_pdfplumber_open):
        mock_pdf = MagicMock()
        mock_page = MagicMock()
        mock_page.extract_text.return_value = "BANCO DO BRASIL\nCOMPROVANTE DE PIX\nDATA: 10/06/2026\nVALOR: 250,50"
        mock_pdf.pages = [mock_page]
        mock_pdfplumber_open.return_value.__enter__.return_value = mock_pdf

        transactions = self.parser.parse("fake_path.pdf")
        
        self.assertEqual(len(transactions), 1)
        self.assertEqual(transactions[0].date, "10/06/2026")
        self.assertEqual(transactions[0].amount_cents, 25050)
        self.assertEqual(transactions[0].type, "expense")

if __name__ == '__main__':
    unittest.main()
