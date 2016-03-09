Mei::Engine.routes.draw do
  get "/mei/terms/:term",  controller: :terms, action: :query
end