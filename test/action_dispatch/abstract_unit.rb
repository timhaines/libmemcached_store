require 'active_support'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/module/attribute_accessors'
require 'action_controller'
require 'action_dispatch/routing'
require 'action_dispatch/middleware/head'
require 'action_dispatch/testing/assertions'
require 'action_dispatch/testing/test_process'
require 'action_dispatch/testing/integration'

SharedTestRoutes = ActionDispatch::Routing::RouteSet.new

class RoutedRackApp
  attr_reader :routes

  def initialize(routes, &blk)
    @routes = routes
    @stack = ActionDispatch::MiddlewareStack.new(&blk).build(@routes)
  end

  def call(env)
    @stack.call(env)
  end
end

class ActionDispatch::IntegrationTest < ActiveSupport::TestCase
  # setup do
  #   @routes = SharedTestRoutes
  # end

  def self.build_app(routes = nil)
    RoutedRackApp.new(routes || ActionDispatch::Routing::RouteSet.new) do |middleware|
      middleware.use "ActionDispatch::ShowExceptions", ActionDispatch::PublicExceptions.new("/dev/null")
      middleware.use "ActionDispatch::DebugExceptions"
      middleware.use "ActionDispatch::Callbacks"
      middleware.use "ActionDispatch::ParamsParser"
      middleware.use "ActionDispatch::Cookies"
      middleware.use "ActionDispatch::Flash"
      middleware.use "ActionDispatch::Head"
      yield(middleware) if block_given?
    end
  end
end