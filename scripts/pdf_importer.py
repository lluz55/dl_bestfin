import os
import re
import json
import argparse
from abc import ABC, abstractmethod
from datetime import datetime
from typing import List, Optional
import pdfplumber
from pydantic import BaseModel

class Transaction(BaseModel):
    date: str
    description: str
    amount_cents: int
    type: str # income, expense
    category_suggestion: Optional[str] = None
    merchant: Optional[str] = None
    account_name: str
    institution: str

class BaseParser(ABC):
    @abstractmethod
    def can_handle(self, text: str) -> bool:
        pass

    @abstractmethod
    def parse(self, pdf_path: str) -> List[Transaction]:
        pass

class NubankCardParser(BaseParser):
    def can_handle(self, text: str) -> bool:
        return "NUBANK" in text.upper() and "FATURA" in text.upper()

    def parse(self, pdf_path: str) -> List[Transaction]:
        transactions = []
        with pdfplumber.open(pdf_path) as pdf:
            for page in pdf.pages:
                text = page.extract_text()
                # Simplified regex for demo, real faturas need robust regex
                # Format: DD MMM Description R$ XX,XX
                matches = re.finditer(r"(\d{2} \w{3})\s+(.+?)\s+R\$\s+([\d.,]+)", text)
                for m in matches:
                    date_str = m.group(1)
                    desc = m.group(2)
                    amount_str = m.group(3).replace(".", "").replace(",", "")
                    
                    transactions.append(Transaction(
                        date=date_str,
                        description=desc,
                        amount_cents=int(amount_str),
                        type="expense",
                        account_name="Cartão Nubank",
                        institution="Nubank"
                    ))
        return transactions

class NubankReceiptParser(BaseParser):
    def can_handle(self, text: str) -> bool:
        upper_text = text.upper()
        return "NUBANK" in upper_text and ("COMPROVANTE" in upper_text or "PIX" in upper_text) and "FATURA" not in upper_text

    def parse(self, pdf_path: str) -> List[Transaction]:
        transactions = []
        with pdfplumber.open(pdf_path) as pdf:
            if not pdf.pages:
                return []
            text = pdf.pages[0].extract_text() or ""
            
            amount_match = re.search(r"R\$\s*([\d.,]+)", text)
            date_match = re.search(r"(\d{2}/\d{2}/\d{4})", text)
            
            if amount_match and date_match:
                amount_str = amount_match.group(1).replace(".", "").replace(",", "")
                is_income = "RECEBIDO" in text.upper() or "RECEBIMENTO" in text.upper()
                tx_type = "income" if is_income else "expense"
                
                transactions.append(Transaction(
                    date=date_match.group(1),
                    description="Pix Recebido" if is_income else "Pix Enviado",
                    amount_cents=int(amount_str),
                    type=tx_type,
                    account_name="Conta Nubank",
                    institution="Nubank"
                ))
        return transactions

class BancoDoBrasilReceiptParser(BaseParser):
    def can_handle(self, text: str) -> bool:
        return "BANCO DO BRASIL" in text.upper() and "COMPROVANTE" in text.upper()

    def parse(self, pdf_path: str) -> List[Transaction]:
        transactions = []
        with pdfplumber.open(pdf_path) as pdf:
            if not pdf.pages:
                return []
            text = pdf.pages[0].extract_text() or ""
            
            amount_match = re.search(r"VALOR.*?([\d.,]+)", text.upper())
            if not amount_match:
                amount_match = re.search(r"R\$\s*([\d.,]+)", text)
                
            date_match = re.search(r"(\d{2}/\d{2}/\d{4})", text)
            
            if amount_match and date_match:
                amount_str = amount_match.group(1).replace(".", "").replace(",", "")
                
                transactions.append(Transaction(
                    date=date_match.group(1),
                    description="Comprovante BB",
                    amount_cents=int(amount_str),
                    type="expense",
                    account_name="Conta BB",
                    institution="Banco do Brasil"
                ))
        return transactions

class PDFImporter:
    def __init__(self):
        self.parsers = [
            NubankCardParser(),
            NubankReceiptParser(),
            BancoDoBrasilReceiptParser(),
        ]

    def process(self, input_path: str):
        all_tx = []
        if os.path.isdir(input_path):
            files = [os.path.join(input_path, f) for f in os.listdir(input_path) if f.endswith(".pdf")]
        else:
            files = [input_path]

        for f in files:
            with pdfplumber.open(f) as pdf:
                text = pdf.pages[0].extract_text() or ""
                
            parser = next((p for p in self.parsers if p.can_handle(text)), None)
            if parser:
                print(f"Using {parser.__class__.__name__} for {f}")
                all_tx.extend(parser.parse(f))
            else:
                print(f"No parser found for {f}")

        return all_tx

def main():
    parser = argparse.ArgumentParser(description="BestFin PDF Importer")
    parser.add_argument("--input", required=True, help="Path to PDF or folder")
    parser.add_argument("--format", default="json", choices=["json", "csv"], help="Output format")
    args = parser.parse_args()

    importer = PDFImporter()
    transactions = importer.process(args.input)

    if args.format == "json":
        print(json.dumps([t.dict() for t in transactions], indent=2, ensure_ascii=False))
    else:
        # Simple CSV output
        print("date,description,amount_cents,type,account_name,institution")
        for t in transactions:
            print(f"{t.date},{t.description},{t.amount_cents},{t.type},{t.account_name},{t.institution}")

if __name__ == "__main__":
    main()
