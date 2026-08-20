# frozen_string_literal: true

RSpec.describe "Bracketed paste" do
  describe Charming::Components::TextInput do
    it "inserts pasted text at the cursor" do
      input = described_class.new(value: "ab", cursor: 1)
      input.handle_paste(Charming::Events::PasteEvent.new(text: "XY"))
      expect(input.value).to eq("aXYb")
      expect(input.cursor).to eq(3)
    end

    it "strips newlines and control characters" do
      input = described_class.new
      input.handle_paste(Charming::Events::PasteEvent.new(text: "one\ntwo\e[31m"))
      expect(input.value).to eq("onetwo[31m")
    end
  end

  describe Charming::Components::TextArea do
    it "preserves newlines in pasted text" do
      area = described_class.new
      area.handle_paste(Charming::Events::PasteEvent.new(text: "one\ntwo"))
      expect(area.value).to eq("one\ntwo")
    end

    it "strips carriage returns from CRLF pastes" do
      area = described_class.new
      area.handle_paste(Charming::Events::PasteEvent.new(text: "one\r\ntwo"))
      expect(area.value).to eq("one\ntwo")
    end
  end

  describe "controller dispatch" do
    it "routes paste events to the focused component" do
      controller_class = Class.new(Charming::Controller) do
        focus_ring :query

        slot(:query) { Charming::Components::TextInput.new(value: session.fetch(:query, "")) }

        def show
          render "query: #{query.value}"
        end

        def query_submitted(value)
          session[:query] = value
          show
        end

        private

        def render_default_action
          session[:query] = query.value
          show
        end
      end
      stub_const("PasteSpecController", controller_class)
      app_class = Class.new(Charming::Application)
      stub_const("PasteSpecApp", app_class)
      app_class.routes do
        root "paste_spec#show"
      end

      backend = Charming::Internal::Terminal::MemoryBackend.new(events: [
        Charming::Events::PasteEvent.new(text: "hello world"),
        Charming::Events::KeyEvent.new(key: :c, ctrl: true) # unbound ctrl+c quits
      ])
      Charming::Runtime.new(PasteSpecApp.new, backend: backend).run

      expect(backend.frames.last).to include("query: hello world")
    end

    it "routes paste events into a focused form's text field" do
      controller_class = Class.new(Charming::Controller) do
        focus_ring :signup_form

        def show
          render "name: #{signup_form.values[:name]}"
        end

        def signup_form
          @signup_form ||= form(:signup) do |f|
            f.input :name
          end
        end

        private

        def render_default_action
          show
        end
      end
      stub_const("FormPasteSpecController", controller_class)
      app_class = Class.new(Charming::Application)
      stub_const("FormPasteSpecApp", app_class)
      app_class.routes do
        root "form_paste_spec#show"
      end

      backend = Charming::Internal::Terminal::MemoryBackend.new(events: [
        Charming::Events::PasteEvent.new(text: "Ada Lovelace"),
        Charming::Events::KeyEvent.new(key: :c, ctrl: true) # unbound ctrl+c quits
      ])
      Charming::Runtime.new(FormPasteSpecApp.new, backend: backend).run

      expect(backend.frames.last).to include("name: Ada Lovelace")
    end
  end

  describe "TTYBackend paste parsing" do
    let(:fake_reader_class) do
      Class.new do
        def initialize(chunks)
          @chunks = chunks
        end

        def read_keypress(**)
          @chunks.shift
        end

        def console
          Struct.new(:keys).new({})
        end
      end
    end

    it "wraps bracketed paste chunks in a PasteEvent" do
      reader = fake_reader_class.new(["\e[200~pasted text\e[201~"])
      backend = Charming::Internal::Terminal::TTYBackend.new(reader: reader)
      event = backend.read_event(timeout: 0.01)

      expect(event).to be_a(Charming::Events::PasteEvent)
      expect(event.text).to eq("pasted text")
    end

    it "accumulates multi-chunk pastes until the end marker" do
      reader = fake_reader_class.new(["\e[200~part one ", "part two\e[201~"])
      backend = Charming::Internal::Terminal::TTYBackend.new(reader: reader)
      event = backend.read_event(timeout: 0.01)

      expect(event.text).to eq("part one part two")
    end
  end
end
