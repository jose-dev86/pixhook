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
    code: "m8 8-4 4 4 4m8-8 4 4-4 4"
  }.freeze

  def icon_svg(name)
    tag.svg(tag.path(d: ICONS.fetch(name)), class: "icon", viewBox: "0 0 24 24", fill: "none",
            stroke: "currentColor", "stroke-width": 2, "stroke-linecap": "round", "stroke-linejoin": "round", aria: { hidden: true })
  end

  def qr_code_svg(text)
    RQRCode::QRCode.new(text).as_svg(module_size: 4, standalone: true, use_path: true, viewbox: true, svg_attributes: { class: "qr" }).html_safe # rubocop:disable Rails/OutputSafety
  end
end
