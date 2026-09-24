# Copyright (c) 2026, Madrasati and Contributors
# For license information, please see license.txt

import frappe
from frappe import _
from frappe.model.document import Document


class TimetableEntry(Document):
	def validate(self):
		self.validate_times()
		self.validate_no_overlap()

	def validate_times(self):
		if not self.start_time or not self.end_time:
			frappe.throw(_("Start time and end time are required"))
		if str(self.end_time) <= str(self.start_time):
			frappe.throw(_("End time must be after start time"))

	def validate_no_overlap(self):
		filters = {"day": self.day}
		if self.name:
			filters["name"] = ["!=", self.name]

		entries = frappe.get_all(
			"Timetable Entry",
			filters=filters,
			fields=["name", "start_time", "end_time", "room", "instructor"],
		)
		for entry in entries:
			if not (str(self.start_time) < str(entry.end_time) and str(entry.start_time) < str(self.end_time)):
				continue
			if self.room and entry.room == self.room:
				frappe.throw(
					_("Room {0} is already booked on {1} from {2} to {3}").format(
						self.room, self.day, entry.start_time, entry.end_time
					)
				)
			if self.instructor and entry.instructor == self.instructor:
				frappe.throw(
					_("Instructor {0} already has a class on {1} from {2} to {3}").format(
						self.instructor, self.day, entry.start_time, entry.end_time
					)
				)
