# Copyright (c) 2026, Madrasati and Contributors
# For license information, please see license.txt

import frappe
from frappe import _
from frappe.model.document import Document
from frappe.utils import today


class HostelAllocation(Document):
	def validate(self):
		self.update_room_occupancy()

	def update_room_occupancy(self):
		room = frappe.db.get_value(
			"Hostel Room", self.room, ["capacity", "occupied", "status"], as_dict=True
		)
		if not room:
			frappe.throw(_("Room {0} not found").format(self.room))

		old_status = None
		if self.name and frappe.db.exists("Hostel Allocation", self.name):
			old_status = frappe.db.get_value("Hostel Allocation", self.name, "status")

		was_active = old_status == "Active"
		is_active = self.status == "Active"
		occupied = cint(room.occupied)

		if is_active and not was_active:
			if occupied >= cint(room.capacity):
				frappe.throw(_("Room {0} is already full").format(self.room))
			occupied += 1
		elif was_active and not is_active:
			occupied = max(occupied - 1, 0)
			if not self.vacate_date:
				self.vacate_date = today()
		else:
			return

		new_status = "Full" if occupied >= cint(room.capacity) else "Available"
		frappe.db.set_value(
			"Hostel Room",
			self.room,
			{"occupied": occupied, "status": new_status},
		)


def cint(value):
	from frappe.utils import cint as _cint

	return _cint(value)
