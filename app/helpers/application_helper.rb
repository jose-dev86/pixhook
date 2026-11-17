module ApplicationHelper
  def money(cents)
    number_to_currency(cents.to_i / 100.0)
  end

  def status_badge(record)
    label = record.class.human_attribute_name("statuses.#{record.status}")
    tag.span(label, class: "badge badge--#{record.status}")
  end

  def event_label(event_type)
    t("webhook_events.types.#{event_type.to_s.tr(".", "_")}", default: event_type)
  end

  def panel_time(time, format: :panel)
    time ? l(time, format:) : t("webhook_events.table.never")
  end

  def nav_link(label, path, icon:)
    active = current_page?(path) || (path != root_path && request.path.start_with?(path))
    link_to path, class: [ "nav__link", { "nav__link--active" => active } ], aria: { current: (active ? "page" : nil) } do
      safe_join([ icon_svg(icon), tag.span(label) ])
    end
  end

  ICONS = {
    home: "M3 10.5 12 3l9 7.5V21h-6v-6H9v6H3z",
    list: "M4 6h16M4 12h16M4 18h10",
    bolt: "M13 2 4 14h7l-1 8 9-12h-7z",
    book: "M4 4h10a4 4 0 0 1 4 4v12H8a4 4 0 0 1-4-4z",
    code: "m8 8-4 4 4 4m8-8 4 4-4 4",
    moon: "M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z",
    sun: "M12 17a5 5 0 1 0 0-10 5 5 0 0 0 0 10zM12 1v2m0 18v2M4.2 4.2l1.4 1.4m12.8 12.8 1.4 1.4M1 12h2m18 0h2M4.2 19.8l1.4-1.4M18.4 5.6l1.4-1.4"
  }.freeze

  def icon_svg(name, class_name: "icon")
    tag.svg(tag.path(d: ICONS.fetch(name)), class: class_name, viewBox: "0 0 24 24", fill: "none",
            stroke: "currentColor", "stroke-width": 2, "stroke-linecap": "round", "stroke-linejoin": "round", aria: { hidden: true })
  end

  def qr_code_svg(text)
    RQRCode::QRCode.new(text).as_svg(module_size: 4, standalone: true, use_path: true, viewbox: true, svg_attributes: { class: "qr" }).html_safe # rubocop:disable Rails/OutputSafety
  end
end
