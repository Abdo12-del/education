# Copyright (c) 2026, Madrasati and Contributors
# For license information, please see license.txt

import frappe
from frappe import _
from frappe.model.document import Document
from frappe.utils import add_days, getdate, today


class LibraryTransaction(Document):
	def validate(self):
		if self.transaction_type == "Issue":
			self.validate_issue()
		elif self.transaction_type == "Return":
			self.validate_return()

	def validate_issue(self):
		if not self.issue_date:
			self.issue_date = today()
		if not self.due_date:
			loan_days = cint(frappe.db.get_single_value("Education Settings", "library_loan_days")) or 14
			self.due_date = add_days(self.issue_date, loan_days)
		if getdate(self.due_date) < getdate(self.issue_date):
			frappe.throw(_("Due date cannot be before issue date"))
		self.status = "Issued"

		book_status = frappe.db.get_value(
			"Library Book", self.book, ["available_copies", "total_copies", "status"], as_dict=True
		)
		if not book_status:
			frappe.throw(_("Book {0} not found").format(self.book))
		if book_status.status != "Available":
			frappe.throw(_("Book {0} is not available for issue").format(self.book))
		if flt(book_status.available_copies) < 1:
			frappe.throw(_("No copies of {0} available").format(self.book))

		opened = frappe.db.count(
			"Library Transaction",
			filters={"book": self.book, "status": "Issued", "name": ["!=", self.name or ""]},
		)
		# keep available copies consistent: total - opened(including this one)
		available = cint(book_status.total_copies) - opened - 1
		frappe.db.set_value("Library Book", self.book, "available_copies", max(available, 0))

	def validate_return(self):
		if not self.return_date:
			self.return_date = today()
		if not self.issue_date:
			self.issue_date = self.return_date
		if not self.due_date:
			loan_days = cint(frappe.db.get_single_value("Education Settings", "library_loan_days")) or 14
			self.due_date = add_days(self.issue_date, loan_days)

		# fine for late return
		fine_per_day = flt(
			frappe.db.get_single_value("Education Settings", "library_fine_per_day")
		)
		late_days = (getdate(self.return_date) - getdate(self.due_date)).days
		self.fine_amount = max(late_days, 0) * fine_per_day
		self.status = "Returned"

		# restore an available copy when the return is recorded (once)
		already_returned = frappe.db.exists(
			"Library Transaction",
			{"name": self.name, "status": "Returned"} if self.name else {"name": "___none___"},
		)
		if not already_returned:
			book = frappe.db.get_value(
				"Library Book", self.book, ["available_copies", "total_copies"], as_dict=True
			)
			if book:
				restored = min(cint(book.available_copies) + 1, cint(book.total_copies))
				frappe.db.set_value("Library Book", self.book, "available_copies", restored)

	def on_cancel(self):
		self.status = "Cancelled" if "Cancelled" in (self.meta.get_field("status").options or "") else self.status


def cint(value):
	from frappe.utils import cint as _cint

	return _cint(value)


def flt(value):
	from frappe.utils import flt as _flt

	return _flt(value)
