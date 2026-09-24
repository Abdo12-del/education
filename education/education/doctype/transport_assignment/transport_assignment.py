# Copyright (c) 2026, Madrasati and Contributors
# For license information, please see license.txt

import frappe
from frappe import _
from frappe.model.document import Document
from frappe.utils import today


class TransportAssignment(Document):
	def validate(self):
		self.validate_single_active_assignment()
		self.set_fee_from_route()

	def validate_single_active_assignment(self):
		if self.status != "Active":
			return
		filters = {"student": self.student, "status": "Active"}
		if self.name:
			filters["name"] = ["!=", self.name]
		conflict = frappe.db.exists("Transport Assignment", filters)
		if conflict:
			frappe.throw(
				_("Student {0} already has an active transport assignment ({1})").format(
					self.student, conflict
				)
			)

	def set_fee_from_route(self):
		if self.route and not self.monthly_fee:
			self.monthly_fee = frappe.db.get_value("Transport Route", self.route, "monthly_fee") or 0
