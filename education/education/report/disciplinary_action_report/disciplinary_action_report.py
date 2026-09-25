# Copyright (c) 2026, Madrasati and Contributors
# License: GNU General Public License v3. See license.txt

import frappe
from frappe import _


def execute(filters=None):
	filters = filters or {}
	conditions = {}
	if filters.get("from_date"):
		conditions["incident_date"] = [">=", filters.get("from_date")]
	if filters.get("to_date"):
		incident = conditions.get("incident_date")
		if isinstance(incident, list):
			incident.append(["<=", filters.get("to_date")])
		else:
			conditions["incident_date"] = ["<=", filters.get("to_date")]
	if filters.get("severity"):
		conditions["severity"] = filters.get("severity")
	if filters.get("status"):
		conditions["status"] = filters.get("status")

	rows = frappe.get_all(
		"Disciplinary Record",
		filters=conditions,
		fields=[
			"name",
			"student",
			"incident_date",
			"incident_type",
			"severity",
			"status",
			"action_type",
			"reported_by",
		],
		order_by="incident_date desc",
	)

	data = []
	for row in rows:
		student_name = frappe.db.get_value("Student", row.student, "student_name") or row.student
		data.append(
			[
				row.name,
				row.student,
				student_name,
				row.incident_date,
				row.incident_type,
				row.severity,
				row.status,
				row.action_type,
				row.reported_by,
			]
		)

	return get_columns(), data


def get_columns():
	return [
		{"fieldname": "name", "label": _("Record"), "fieldtype": "Link", "options": "Disciplinary Record", "width": 150},
		{"fieldname": "student", "label": _("Student"), "fieldtype": "Link", "options": "Student", "width": 110},
		{"fieldname": "student_name", "label": _("Student Name"), "fieldtype": "Data", "width": 150},
		{"fieldname": "incident_date", "label": _("Date"), "fieldtype": "Date", "width": 100},
		{"fieldname": "incident_type", "label": _("Incident"), "fieldtype": "Data", "width": 150},
		{"fieldname": "severity", "label": _("Severity"), "fieldtype": "Data", "width": 90},
		{"fieldname": "status", "label": _("Status"), "fieldtype": "Data", "width": 100},
		{"fieldname": "action_type", "label": _("Action"), "fieldtype": "Data", "width": 130},
		{"fieldname": "reported_by", "label": _("Reported By"), "fieldtype": "Link", "options": "Instructor", "width": 130},
	]
