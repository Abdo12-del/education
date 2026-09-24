# Copyright (c) 2026, Madrasati and Contributors
# For license information, please see license.txt

import frappe
from frappe import _
from frappe.model.document import Document


class LibraryMember(Document):
	def validate(self):
		self.validate_member_target()
		self.set_member_name()

	def validate_member_target(self):
		if self.member_type == "Student" and not self.student:
			frappe.throw(_("Student is required for student members"))
		if self.member_type == "Instructor" and not self.instructor:
			frappe.throw(_("Instructor is required for instructor members"))
		if self.member_type == "Student" and self.instructor:
			self.instructor = None
		if self.member_type == "Instructor" and self.student:
			self.student = None

	def set_member_name(self):
		if self.member_type == "Student" and self.student:
			self.member_name = (
				frappe.db.get_value("Student", self.student, "student_name") or self.student
			)
		elif self.member_type == "Instructor" and self.instructor:
			self.member_name = (
				frappe.db.get_value("Instructor", self.instructor, "instructor_name")
				or self.instructor
			)
