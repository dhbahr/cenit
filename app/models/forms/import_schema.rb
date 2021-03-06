module Forms
  class ImportSchema
    include Mongoid::Document

    belongs_to :library, class_name: Setup::Library.to_s
    field :data, type: String
    field :base_uri, type: String

    validates_presence_of :library, :data

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
      edit do

        field :library do
          inline_edit false
        end

        field :data do
          render do
            bindings[:form].file_field(self.name, self.html_attributes.reverse_merge(data: {fileupload: true}))
          end
        end

        field :base_uri
      end
    end
  end
end
