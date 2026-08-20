# frozen_string_literal: true

RSpec.describe Charming::Layout::Builder do
  let(:screen) { Charming::Screen.new(width: 10, height: 3) }
  let(:view) { Charming::View.new(screen: screen) }

  def build_layout(screen: self.screen, view: self.view, &)
    described_class.build(screen: screen, view: view, &).render
  end

  it "renders a horizontal split with fixed and growing panes" do
    output = build_layout do
      split :horizontal, gap: 1 do
        pane width: 3 do
          "AAA\nBBB"
        end

        pane grow: 1 do
          "CCCC\nDDDD"
        end
      end
    end

    expect(output).to eq("AAA CCCC  \nBBB DDDD  \n          ")
  end

  it "renders a vertical split with fixed and growing panes" do
    output = build_layout(screen: Charming::Screen.new(width: 5, height: 4)) do
      split :vertical, gap: 1 do
        pane height: 1 do
          "AAAAA"
        end

        pane grow: 1 do
          "B"
        end
      end
    end

    expect(output).to eq("AAAAA\n     \nB    \n     ")
  end

  it "renders pane border and padding inside the assigned outer size" do
    output = build_layout(screen: Charming::Screen.new(width: 8, height: 5)) do
      pane border: :normal, padding: 1 do
        "X"
      end
    end

    expect(output).to eq("+------+\n|      |\n| X    |\n|      |\n+------+")
  end

  it "yields the pane content rect to pane blocks" do
    output = build_layout(screen: Charming::Screen.new(width: 8, height: 5)) do
      pane border: :normal, padding: 1 do |rect|
        "#{rect.width}x#{rect.height}"
      end
    end

    expect(output).to include("4x1")
  end

  it "yields positioned rects for panes inside splits" do
    rects = []
    layout = described_class.build(screen: Charming::Screen.new(width: 10, height: 3), view: view) do
      split :horizontal, gap: 1 do
        pane width: 3 do |rect|
          rects << rect
          "L"
        end

        pane grow: 1 do |rect|
          rects << rect
          "R"
        end
      end
    end

    layout.render

    expect(rects).to eq([
      Charming::Layout::Rect.new(x: 0, y: 0, width: 3, height: 3),
      Charming::Layout::Rect.new(x: 4, y: 0, width: 6, height: 3)
    ])
  end

  it "clips oversized pane content" do
    output = build_layout(screen: Charming::Screen.new(width: 4, height: 2)) do
      pane do
        "abcdef\nghijkl\nmnop"
      end
    end

    expect(output).to eq("abcd\nghij")
  end

  it "centers overlays on top of the root layout" do
    output = build_layout(screen: Charming::Screen.new(width: 5, height: 3)) do
      pane do
        ".....\n.....\n....."
      end

      overlay "X"
    end

    expect(output).to eq(".....\n..X..\n.....")
  end

  it "is available as a view helper" do
    view_class = Class.new(Charming::View) do
      def render
        screen_layout do
          split :horizontal do
            pane width: 2 do
              "A"
            end

            pane do
              "B"
            end
          end
        end
      end
    end

    output = view_class.new(screen: Charming::Screen.new(width: 4, height: 1)).render

    expect(output).to eq("A B ")
  end

  it "collects focusable panes in declaration order" do
    layout = described_class.build(screen: screen, view: view) do
      split :horizontal do
        pane(:left, width: 2, focus: true) { "L" }
        pane(:decoration, width: 1) { "|" }
        pane(:right, grow: 1, focus: true) { "R" }
      end
    end

    expect(layout.focusable_names).to eq(%i[left right])
  end

  it "collects named pane mouse targets with outer and inner bounds" do
    layout = described_class.build(screen: Charming::Screen.new(width: 12, height: 5), view: view) do
      split :horizontal, gap: 1 do
        pane(:left, width: 8, border: true, padding: 1) { "L" }
        pane(:right, grow: 1) { "R" }
      end
    end

    expect(layout.mouse_targets).to eq([
      {
        name: :left,
        rect: Charming::Layout::Rect.new(x: 0, y: 0, width: 8, height: 5),
        inner_rect: Charming::Layout::Rect.new(x: 2, y: 2, width: 4, height: 1)
      },
      {
        name: :right,
        rect: Charming::Layout::Rect.new(x: 9, y: 0, width: 3, height: 5),
        inner_rect: Charming::Layout::Rect.new(x: 9, y: 0, width: 3, height: 5)
      }
    ])
  end

  it "registers focusable panes and applies focused pane styling" do
    controller_class = Class.new(Charming::Controller) do
      focus_ring :left, :right
    end
    stub_const("LayoutFocusSpecController", controller_class)
    controller = LayoutFocusSpecController.new(application: Charming::Application.new)
    view_class = Class.new(Charming::View) do
      def render
        screen_layout do
          split :horizontal do
            pane(:left, width: 2, focus: true, style: style.foreground(:red), focused_style: style.foreground(:green)) { "L" }
            pane(:right, grow: 1, focus: true, style: style.foreground(:red), focused_style: style.foreground(:green)) { "R" }
          end
        end
      end
    end
    view = view_class.new(screen: Charming::Screen.new(width: 4, height: 1), controller: controller)

    expect(view.render).to include("\e[32mL")
    expect(controller.focus.current).to eq(:left)

    controller.focus.cycle

    expect(view.render).to include("\e[32mR")
    expect(controller.focus.current).to eq(:right)
  end
end
