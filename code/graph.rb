#!/usr/bin/env ruby -w

require 'gtk2'

edges = [[:a, :b], 
         [:a, :c], 
         [:b, :c], 
         [:c, :d],
         [:d, :e],
         [:d, :f],
         [:e, :f],
        ]

dot = "graph Test {\n"
edges.each do |edge|
  dot << "    #{edge[0].to_s} -- #{edge[1].to_s};\n"
end
dot << "}\n"

layout = IO.popen('neato -Tplain', 'r+') do |pipe|
  pipe.write(dot)
  pipe.close_write
  pipe.read
end

vertex_coordinates = {}
padding            = 20
scale              = 100

layout.each do |line|
  if line =~ /^node (\w+)  ([\d.]+) ([\d.]+)/
    vertex_coordinates[$1.to_sym] = [$2.to_f * scale + padding, 
                                     $3.to_f * scale + padding]
  end
end

window = Gtk::Window.new('Graph')
window.set_default_size(400, 400)

window.signal_connect('destroy') do
  Gtk.main_quit
end

area = Gtk::DrawingArea.new
area.signal_connect('expose_event') do
  context = area.window.create_cairo_context

  # Draw the edges as straight lines between the centers of the
  # vertices.
  edges.each do |edge|
    context.move_to(*vertex_coordinates[edge[0]])
    context.line_to(*vertex_coordinates[edge[1]])
    context.stroke
  end

  vertex_coordinates.each do |v, c|
    # Draw the vertex as a circle filled with white (this hides
    # the edges underneath)
    context.arc(c[0], c[1], 20, 0, 2.0 * Math::PI)
    context.set_source_rgb(1, 1, 1)
    context.fill_preserve()
    context.set_source_rgb(0, 0, 0)
    context.stroke

    # Draw the vertex labels
    context.set_font_size(16)
    context.select_font_face('Arial', 'normal', 'bold');
    context.move_to(c[0] - 6, c[1] + 5)
    context.show_text(v.to_s.upcase)
    context.stroke
  end
end

window.add(area)
window.show_all

Gtk.main
