# frozen_string_literal: true

module Charming
  # View is the base class for all screen view implementations. It provides assign injection (via `initialize`),
  # rendering hooks, layout composition helpers (`row`, `column`, `render_component`, `yield_content`),
  # and access to controller theme, style, and focus state from within views.
  class View
    # Initializes the view with named assigns injected as instance-local accessor methods via
    # `define_singleton_method`. Called when a controller instantiates a view for rendering.
    def initialize(**assigns)
      @assigns = assigns
      define_assign_readers
    end

    # Returns all view assigns as a hash, used by layouts to compose the full template (content + screen + controller).
    def layout_assigns
      assigns
    end

    # Renders the view's body. Default is empty — subclasses override to return visible text.
    def render
      ""
    end

    # Delegates focus checking to the controller in assigns, allowing views to determine which slot (sidebar, content) has focus.
    def focused?(slot)
      ctrl = assigns[:focus_controller] || assigns[:controller]
      ctrl ? ctrl.focused?(slot) : false
    end

    private

    attr_reader :assigns

    # Returns the shared UI style configuration used by components and views for visual rendering (colors, borders).
    def style
      UI.style
    end

    # Returns the active theme: uses `theme` from assigns or controller, falling back to `UI::Theme.default`.
    def theme
      assigns[:theme] || assigns[:controller]&.theme || UI::Theme.default
    end

    # Outputs styled text through the view's rendering pipeline. Accepts a named `style:` for inline formatting.
    # Appends the rendered value to the output buffer and returns it.
    def text(value, style: nil)
      rendered = apply_style(value.to_s, style)
      append_to_buffer(rendered)
      rendered
    end

    # Renders a box with optional styling. Accepts an inline block for complex content or a plain value.
    # Used for bordered containers and field groups in views.
    def box(value = nil, style: nil, &)
      content = block_given? ? capture(&) : value.to_s
      apply_style(content, style)
    end

    # Joins items horizontally (side-by-side) using the UI rendering engine. Supports `gap:`
    # spacing and cross-axis `align:` (`:top`/`:center`/`:bottom` or a 0.0–1.0 fraction).
    def row(*items, gap: 0, align: :top)
      UI.join_horizontal(*items, gap: gap, align: align)
    end

    # Stacks items vertically using the UI rendering engine. Supports `gap:` spacing and
    # cross-axis `align:` (`:left`/`:center`/`:right` or a 0.0–1.0 fraction).
    def column(*items, gap: 0, align: :left)
      UI.join_vertical(*items, gap: gap, align: align)
    end

    # Renders a component (e.g., a ProgressBar, Spinner, Modal) and returns its string output.
    def render_component(component)
      component.render.to_s
    end

    # Renders a partial view component. An alias for `render_component` used in layout templates.
    def render_partial(partial)
      render_component(partial)
    end

    # Builds a declarative layout tree for the current terminal screen and renders it.
    def screen_layout(background: nil, &)
      layout = Layout::Builder.build(screen: layout_screen, view: self, background: background, &)
      register_layout_focus(layout)
      register_layout_mouse_targets(layout)
      layout.render
    end

    # Yields the layout's `content` slot — used by view templates to inject their body into a layout wrapper (e.g., sidebar).
    def yield_content
      assigns.fetch(:content, "")
    end

    # Evaluates a block in the view's context with a clean output buffer. Captures text written via `text`/`box`
    # and returns joined content. Resets buffer afterward for parent rendering.
    def capture(&)
      previous_buffer = @output_buffer
      @output_buffer = []
      result = instance_eval(&)
      @output_buffer.empty? ? result.to_s : @output_buffer.join("\n")
    ensure
      @output_buffer = previous_buffer
    end

    # Appends a value to the current output buffer (if one is active). Used by rendering helpers.
    def append_to_buffer(value)
      @output_buffer << value if @output_buffer
    end

    # Applies a style object's `render` method to a string, returning styled output or raw text when style is nil.
    def apply_style(value, style_object)
      style_object ? style_object.render(value) : value
    end

    # Dynamically defines read-only accessor methods for each assign key as singleton methods on self.
    # Skips keys where the view already responds (controller methods take precedence).
    def define_assign_readers
      assigns.each_key do |name|
        next if respond_to?(name, true)

        define_singleton_method(name) { assigns.fetch(name) }
      end
    end

    def layout_screen
      assigns[:screen] || assigns[:controller]&.screen || Charming::Screen.new(width: 80, height: 24)
    end

    def register_layout_focus(layout)
      return unless assigns[:controller]

      assigns[:controller].register_layout_focus(layout.focusable_names)
    end

    def register_layout_mouse_targets(layout)
      return unless assigns[:controller]

      assigns[:controller].register_mouse_targets(layout.mouse_targets)
    end
  end
end
