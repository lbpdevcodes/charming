# frozen_string_literal: true

RSpec.describe Charming::Router do
  before do
    stub_const("RouterSpecController", Class.new(Charming::Controller))
  end

  it "resolves the root screen by its reserved name" do
    router = described_class.new

    router.draw do
      root "router_spec#show"
    end

    route = router.resolve(:root)

    expect(route.name).to eq(:root)
    expect(route.controller_class).to eq(RouterSpecController)
    expect(route.action).to eq(:show)
    expect(route.params).to eq({})
  end

  it "resolves named screens with a default action" do
    router = described_class.new

    router.draw do
      screen :projects, "router_spec"
    end

    expect(router.resolve(:projects).action).to eq(:show)
  end

  it "resolves controller actions inside a namespace" do
    stub_const("RouterSpecApp", Module.new)
    stub_const("RouterSpecApp::HomeController", Class.new(Charming::Controller))
    router = described_class.new(namespace: "RouterSpecApp")

    router.draw do
      root "home#show"
    end

    route = router.resolve(:root)

    expect(route.controller_class).to eq(RouterSpecApp::HomeController)
    expect(route.action).to eq(:show)
  end

  it "resolves nested controller paths inside a namespace" do
    stub_const("RouterSpecApp", Module.new)
    stub_const("RouterSpecApp::Admin", Module.new)
    stub_const("RouterSpecApp::Admin::UsersController", Class.new(Charming::Controller))
    router = described_class.new(namespace: "RouterSpecApp")

    router.draw do
      screen :admin_users, "admin/users#show"
    end

    route = router.resolve(:admin_users)

    expect(route.controller_class).to eq(RouterSpecApp::Admin::UsersController)
    expect(route.action).to eq(:show)
  end

  it "passes params through untouched" do
    router = described_class.new
    entry = Object.new

    router.draw do
      screen :project, "router_spec#show"
    end

    route = router.resolve(:project, id: 5, entry: entry)

    expect(route.params).to eq(id: 5, entry: entry)
  end

  it "does not mutate the registered route when resolving with params" do
    router = described_class.new

    router.draw do
      screen :project, "router_spec#show"
    end

    router.resolve(:project, id: 5)

    expect(router.resolve(:project).params).to eq({})
  end

  it "raises KeyError listing registered names on an unknown screen" do
    router = described_class.new

    router.draw do
      root "router_spec#show"
      screen :projects, "router_spec#index"
    end

    expect { router.resolve(:projets) }
      .to raise_error(KeyError, /projets.*:root.*:projects/)
  end

  it "raises ArgumentError with a migration hint for a string path" do
    router = described_class.new

    expect { router.draw { screen "/projects", to: "router_spec#index" } }
      .to raise_error(ArgumentError, /screen :projects/)
  end

  it "derives a title from the screen name" do
    router = described_class.new

    router.draw do
      screen :project_list, "router_spec#index"
    end

    expect(router.resolve(:project_list).title).to eq("Project List")
  end

  it "prefers an explicit title over the derived one" do
    router = described_class.new

    router.draw do
      screen :projects, "router_spec#index", title: "All Projects"
    end

    expect(router.resolve(:projects).title).to eq("All Projects")
  end

  it "defaults the root title to Home" do
    router = described_class.new

    router.draw do
      root "router_spec#show"
    end

    expect(router.resolve(:root).title).to eq("Home")
  end

  it "returns all registered routes in insertion order" do
    router = described_class.new

    router.draw do
      root "router_spec#show"
      screen :projects, "router_spec#index"
    end

    expect(router.all.map(&:name)).to eq(%i[root projects])
  end
end
