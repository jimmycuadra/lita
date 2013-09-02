module Lita
  module RSpec
    # Object containing a [Lita::Message] and a [Lita::Target]
    MessageReceipt = Struct.new(:target, :message)

    # Extras for +RSpec+ to facilitate testing Lita handlers.
    module Handler
      class << self
        # Sets up the RSpec environment to easily test Lita handlers.
        def included(base)
          base.class_eval do
            include Lita::RSpec
          end

          set_up_let_blocks(base)
          set_up_subject(base)
          set_up_before_block(base)
        end

        private

        # Stub Lita.handlers and Lita::Robot#send_messages.
        def set_up_before_block(base)
          base.class_eval do
            before do
              allow(Lita).to receive(:handlers).and_return([described_class])
              [:send_messages, :send_message].each do |message|
                allow(robot).to receive(message) do |target, *strings|
                  message_receipts.concat(strings.map do |s|
                    MessageReceipt.new(target, s)
                  end)
                  replies.concat(strings)
                end
              end
            end
          end
        end

        # Create common test objects.
        def set_up_let_blocks(base)
          base.class_eval do
            let(:robot) { Robot.new }
            let(:source) { Source.new(user) }
            let(:user) { User.create("1", name: "Test User") }
            let(:replies) { [] }
            let(:message_receipts) { [] }
          end
        end

        # Set up a working test subject.
        def set_up_subject(base)
          base.class_eval do
            subject { described_class.new(robot) }
          end
        end
      end

      # Sends a message to the robot.
      # @param body [String] The message to send.
      # @param as [Lita::User] The user sending the message.
      # @return [void]
      def send_message(body, as: user)
        message = if as == user
          Message.new(robot, body, source)
        else
          Message.new(robot, body, Source.new(as))
        end

        robot.receive(message)
      end

      # Sends a "command" message to the robot.
      # @param body [String] The message to send.
      # @param as [Lita::User] The user sending the message.
      # @return [void]
      def send_command(body, as: user)
        send_message("#{robot.mention_name}: #{body}", as: as)
      end

      # Starts a chat routing test chain, asserting that a message should
      # trigger a route.
      # @param message [String] The message that should trigger the route.
      # @return [RouteMatcher] A {RouteMatcher} that should have +to+ called on
      #   it to complete the test.
      def routes(message)
        RouteMatcher.new(self, message)
      end

      # Starts a chat routing test chain, asserting that a message should not
      # trigger a route.
      # @param message [String] The message that should not trigger the route.
      # @return [RouteMatcher] A {RouteMatcher} that should have +to+ called on
      #   it to complete the test.
      def does_not_route(message)
        RouteMatcher.new(self, message, invert: true)
      end
      alias_method :doesnt_route, :does_not_route

      # Starts a chat routing test chain, asserting that a "command" message
      # should trigger a route.
      # @param message [String] The message that should trigger the route.
      # @return [RouteMatcher] A {RouteMatcher} that should have +to+ called on
      #   it to complete the test.
      def routes_command(message)
        RouteMatcher.new(self, "#{robot.mention_name}: #{message}")
      end

      # Starts a chat routing test chain, asserting that a "command" message
      # should not trigger a route.
      # @param message [String] The message that should not trigger the route.
      # @return [RouteMatcher] A {RouteMatcher} that should have +to+ called on
      #   it to complete the test.
      def does_not_route_command(message)
        RouteMatcher.new(
          self,
          "#{robot.mention_name}: #{message}",
          invert: true
        )
      end
      alias_method :doesnt_route_command, :does_not_route_command

      # Starts an HTTP routing test chain, asserting that a request to the given
      # path with the given HTTP request method will trigger a route.
      # @param http_method [Symbol] The HTTP request method that should trigger
      #   the route.
      # @param path [String] The path URL component that should trigger the
      #   route.
      # @return [HTTPRouteMatcher] An {HTTPRouteMatcher} that should have +to+
      #   called on it to complete the test.
      def routes_http(http_method, path)
        HTTPRouteMatcher.new(self, http_method, path)
      end

      # Starts an HTTP routing test chain, asserting that a request to the given
      # path with the given HTTP request method will not trigger a route.
      # @param http_method [Symbol] The HTTP request method that should not
      #   trigger the route.
      # @param path [String] The path URL component that should not trigger the
      #   route.
      # @return [HTTPRouteMatcher] An {HTTPRouteMatcher} that should have +to+
      #   called on it to complete the test.
      def does_not_route_http(http_method, path)
        HTTPRouteMatcher.new(self, http_method, path, invert: true)
      end
      alias_method :doesnt_route_http, :does_not_route_http
    end

    # Used to complete a chat routing test chain.
    class RouteMatcher
      def initialize(context, message_body, invert: false)
        @context = context
        @message_body = message_body
        @method = invert ? :not_to : :to
      end

      # Sets an expectation that a route will or will not be triggered, then
      # sends the message originally provided.
      # @param route [Symbol] The name of the method that should or should not
      #   be triggered.
      # @return [void]
      def to(route)
        m = @method
        b = @message_body

        @context.instance_eval do
          allow(Authorization).to receive(:user_in_group?).and_return(true)
          expect_any_instance_of(described_class).public_send(m, receive(route))
          send_message(b)
        end
      end
    end

    # Used to complete an HTTP routing test chain.
    class HTTPRouteMatcher
      def initialize(context, http_method, path, invert: false)
        @context = context
        @http_method = http_method
        @path = path
        @method = invert ? :not_to : :to
      end

      # Sets an expectation that an HTTP route will or will not be triggered,
      #   then makes an HTTP request against the app with the HTTP request
      #   method and path originally provided.
      # @param route [Symbol] The name of the method that should or should not
      #   be triggered.
      # @return [void]
      def to(route)
        m = @method
        h = @http_method
        p = @path

        @context.instance_eval do
          expect_any_instance_of(described_class).public_send(m, receive(route))
          env = Rack::MockRequest.env_for(p, method: h)
          robot.app.call(env)
        end
      end
    end
  end
end
