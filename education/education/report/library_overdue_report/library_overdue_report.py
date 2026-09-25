# Copyright (c) 2026, Madrasati and Contributors
# License: GNU General Public License v3. See license.txt

import frappe
from frappe import _
from frappe.utils import flt, getdate, today


def execute(filters=None):
	filters = filters or {}
	overdue_days = int(filters.get("overdue_days") or 0)

	conditions = {"status": "Issued", "due_date": ["<", today()]}
	if overdue_days:
		from frappe.utils import add_days

		conditions["due_date"] = ["<", add_days(today(), -overdue_days)]

	rows = frappe.get_all(
		"Library Transaction",
		filters=conditions,
		fields=["name", "book", "member", "issue_date", "due_date"],
		order_by="due_date asc",
	)

	fine_per_day = flt(frappe.db.get_single_value("Education Settings", "library_fine_per_day"))
	data = []
	for row in rows:
		book_title = frappe.db.get_value("Library Book", row.book, "book_title") or row.book
		member = frappe.db.get_value(
			"Library Member", row.member, ["member_name", "member_type", "student", "instructor"],
			as_dict=True,
		) or {}
		member_label = member.get("member_name") or row.member
		days_overdue = (getdate(today()) - getdate(row.due_date)).days
		data.append(
			[
				row.book,
				book_title,
				row.member,
				member_label,
				member.get("member_type"),
				row.issue_date,
				row.due_date,
				days_overdue,
				days_overdue * fine_per_day,
			]
		)

	columns = get_columns()
	return columns, data


def get_columns():
	return [
		{"fieldname": "book", "label": _("Book"), "fieldtype": "Link", "options": "Library Book", "width": 90},
		{"fieldname": "book_title", "label": _("Title"), "fieldtype": "Data", "width": 200},
		{"fieldname": "member", "label": _("Member"), "fieldtype": "Link", "options": "Library Member", "width": 110},
		{"fieldname": "member_name", "label": _("Member Name"), "fieldtype": "Data", "width": 150},
		{"fieldname": "member_type", "label": _("Type"), "fieldtype": "Data", "width": 90},
		{"fieldname": "issue_date", "label": _("Issue Date"), "fieldtype": "Date", "width": 110},
		{"fieldname": "due_date", "label": _("Due Date"), "fieldtype": "Date", "width": 110},
		{"fieldname": "days_overdue", "label": _("Days Overdue"), "fieldtype": "Int", "width": 110},
		{"fieldname": "fine", "label": _("Fine"), "fieldtype": "Currency", "width": 100},
	]
