module RailsAdmin
  module Config
    module Actions
      class Submit < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Webhook
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            render_form = true
            if model = @abstract_model.model rescue nil
              connection =
                if data = params.delete((model_name = @action.class.name.split('::').last + 'Form').underscore)
                  data.permit!
                  connection = Setup::Connection.where(id: data[:connection_id]).first
                else
                  selecting_connection = true
                  @object.connections.first || Setup::Connection.where(namespace: @object.namespace).first
                end unless params.delete(:_restart)
              mongoff_model = Mongoff::Model.for(data_type: model.data_type,
                                                 schema: Submit.params_schema(@object, selecting_connection ? nil : connection),
                                                 name: model_name)
              if params.delete(:_save) && (@form_object = mongoff_model.new(data)).valid?
                msg = Submit.params_and_headers_from(@form_object.attributes).merge!(webhook_id: @object.id,
                                                                                     connection_id: connection.id,
                                                                                     body: data[:body])
                do_flash_process_result Setup::Submission.process(msg)
                render_form = false
              end
            else
              flash[:error] = 'Error loading model'
            end
            if render_form
              @form_object ||= mongoff_model.new(connection: connection)
              @form_object.define_singleton_method(:ready_to_save?) { !selecting_connection && connection.present? }
              @form_object.define_singleton_method(:can_be_restarted?) { ready_to_save? }
              @model_config = RailsAdmin::Config.model(mongoff_model)
              @model_config.register_instance_option(:discard_submit_buttons) { true }
              if connection
                @model_config.configure(:connection).associated_collection_scope do
                  Proc.new { |scope|
                    scope.where(id: connection.id)
                  }
                end
              end unless selecting_connection
              if @form_object.errors.present?
                do_flash(:error, 'There are errors in the import data specification', @form_object.errors.full_messages)
              end

              render :form
            else
              redirect_to back_or_index
            end

          end
        end

        register_instance_option :link_icon do
          'icon-play-circle'
        end

        class << self

          def params_and_headers_from(data)
            params = Hash.new { |h, k| h[k] = {} }
            data.each do |name, value|
              if prefix = %w(header parameter template_parameter).detect { |p| name.to_s.start_with?(p) }
                params[prefix.pluralize][name.from(prefix.length + 1)] = value
              end
            end
            if (contentType = data['content_type']).present?
              params['headers']['Content-Type'] = contentType
            end
            params
          end

          def params_schema(webhook, connection)
            required = ['connection']
            pararms_properties =
              if connection
                [connection, webhook].inject({}) do |hash, entity|
                  entity_hash = [:headers, :parameters, :template_parameters].inject({}) do |hash, params|
                    prefix = params.to_s.singularize
                    h = entity.send(params).inject({}) do |params_hash, param|
                      params_hash[property_name = "#{prefix}_#{param.key}"] =
                        ph =
                          (param.metadata || {}).deep_dup.merge!('title' => param.key,
                                                                 'description' => param.description,
                                                                 'group' => params.to_s)
                      ph['type'] ||= 'string'
                      if value = param.value
                        ph['default'] = value
                      end
                      required << property_name if ph.delete('required')
                      params_hash
                    end
                    hash.merge! h
                  end
                  hash.deep_merge! entity_hash
                end
              else
                {}
              end
            if connection && %(get delete).exclude?(webhook.method)
              content_type_property =
                {
                  'type' => 'string',
                  'group' => 'body'
                }
              body_properties =
                {
                  'content_type' => content_type_property,
                  'body' => {
                    'type' => 'string',
                    'group' => 'body'
                  }
                }
              if consumes = webhook.metadata['consumes']
                consumes = [consumes] unless consumes.is_a?(Enumerable)
                content_type_property['default'] = consumes.first.to_s
              end
              pararms_properties.merge!(body_properties)
            end
            {
              'type' => 'object',
              'required' => required,
              'properties' => {
                'connection' => {
                  '$ref' => Setup::Connection.to_s,
                  'referenced' => true
                }
              }.merge!(pararms_properties)
            }
          end
        end
      end
    end
  end
end