# frozen_string_literal: true

DemoApp::Application.routes do
  root "home#show"
  screen :lg, "lg#show", title: "LG Layout"
  screen :image, "image#show", title: "Image"
  screen :charts, "charts#show", title: "Charts"
  screen :physics, "physics#show", title: "Physics"
end
