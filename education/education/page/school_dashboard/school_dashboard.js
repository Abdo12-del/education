// Copyright (c) 2026, Madrasati and Contributors
// License: GNU General Public License v3. See license.txt

frappe.pages["school_dashboard"].on_page_load = function (wrapper) {
	const page = frappe.ui.make_app_page({
		parent: wrapper,
		title: __("Madrasati Dashboard"),
		single_column: true,
	});

	const $content = $(`<div class="madrasati-dashboard" style="padding:12px 4px;"></div>`).appendTo(page.body);

	$content.html(`
		<div id="madrasati-cards" class="row" style="display:flex;flex-wrap:wrap;gap:12px;"></div>
		<div style="display:flex;gap:16px;flex-wrap:wrap;margin-top:20px;">
			<div id="madrasati-notices" style="flex:1 1 340px;min-width:300px;"></div>
			<div id="madrasati-overdue" style="flex:1 1 340px;min-width:300px;"></div>
		</div>
	`);

	frappe.call({
		method: "education.education.api.get_school_overview",
		callback: function (r) {
			render_cards($content.find("#madrasati-cards"), r.message || {});
			render_notices($content.find("#madrasati-notices"), (r.message || {}).recent_notices || []);
			render_overdue($content.find("#madrasati-overdue"), (r.message || {}).overdue_books || []);
		},
	});

	function card(label, value, color) {
		return `
			<div style="flex:1 1 170px;min-width:160px;background:var(--card-bg,#fff);
				border:1px solid var(--border-color,#e5e7eb);border-radius:8px;padding:14px 16px;
				box-shadow:0 1px 2px rgba(0,0,0,0.04);">
				<div style="font-size:12px;color:var(--text-muted,#6b7280);text-transform:uppercase;letter-spacing:.04em;">${label}</div>
				<div style="font-size:26px;font-weight:600;color:${color || "inherit"};margin-top:6px;">${value}</div>
			</div>`;
	}

	function render_cards($el, m) {
		const html = [
			card(__("Students"), m.students || 0, "#2563eb"),
			card(__("Instructors"), m.instructors || 0, "#0d9488"),
			card(__("Attendance Today"), `${m.attendance_present || 0} / ${m.attendance_today || 0}`, "#16a34a"),
			card(__("Absent Today"), m.attendance_absent || 0, "#dc2626"),
			card(__("Collected (Month)"), format_currency(m.fees_collected_month || 0), "#16a34a"),
			card(__("Outstanding Fees"), format_currency(m.fees_outstanding || 0), "#d97706"),
			card(__("Library Issued"), m.library_issued || 0, "#7c3aed"),
			card(__("Overdue Books"), m.library_overdue || 0, "#dc2626"),
			card(__("Open Discipline"), m.discipline_open || 0, "#dc2626"),
			card(__("Transport Users"), m.transport_active || 0, "#0d9488"),
			card(__("Hostel Occupied"), `${m.hostel_occupied || 0} / ${m.hostel_rooms || 0}`, "#7c3aed"),
			card(__("Certificates (Month)"), m.certificates_month || 0, "#2563eb"),
			card(__("Recent Admissions"), m.recent_admissions || 0, "#0d9488"),
			card(__("Published Notices"), m.notices || 0, "#d97706"),
		].join("");
		$el.html(html);
	}

	function panel(title) {
		return `<div style="background:var(--card-bg,#fff);border:1px solid var(--border-color,#e5e7eb);
			border-radius:8px;padding:14px 16px;height:100%;">
			<h4 style="margin:0 0 10px;font-size:14px;text-transform:uppercase;letter-spacing:.04em;color:var(--text-muted,#6b7280);">${title}</h4>
			<div class="panel-body"></div></div>`;
	}

	function render_notices($el, notices) {
		$el.html(panel(__("Latest Notices")));
		const $body = $el.find(".panel-body");
		if (!notices.length) {
			$body.html(`<span style="color:var(--text-muted,#9ca3af);">${__("No notices yet")}</span>`);
			return;
		}
		$body.html(
			notices
				.map(
					(n) => `
				<div style="padding:8px 0;border-bottom:1px dashed var(--border-color,#eee);">
					<div style="font-weight:600;">${frappe.utils.escape_html(n.title)}</div>
					<div style="font-size:12px;color:var(--text-muted,#6b7280);">${n.notice_type} · ${frappe.datetime.str_to_user(n.publish_date)}</div>
				</div>`
				)
				.join("")
		);
	}

	function render_overdue($el, books) {
		$el.html(panel(__("Overdue Books")));
		const $body = $el.find(".panel-body");
		if (!books.length) {
			$body.html(`<span style="color:var(--text-muted,#9ca3af);">${__("No overdue books — great job!")}</span>`);
			return;
		}
		$body.html(
			books
				.map(
					(b) => `
				<div style="padding:8px 0;border-bottom:1px dashed var(--border-color,#eee);">
					<div style="font-weight:600;">${frappe.utils.escape_html(b.book_title || b.book)}</div>
					<div style="font-size:12px;color:var(--text-muted,#6b7280);">${__("Due")}: ${frappe.datetime.str_to_user(b.due_date)}</div>
				</div>`
				)
				.join("")
		);
	}
};
