module Setup
  class AlgorithmExecution < Setup::Task

    BuildInDataType.regist(self)

    belongs_to :algorithm, class_name: Setup::Algorithm.to_s, inverse_of: nil
    belongs_to :user_script, class_name: Setup::UserScript.to_s, inverse_of: nil

    before_save do
      self.algorithm = Setup::Algorithm.where(id: message[:object_key]).first
      self.user_script = Setup::UserScript.where(id: message[:object_key]).first
    end

    def run(message)
      _Model = Setup::Algorithm
      if self.user_script
        _Model = Setup::UserScript
      end
      if runnable = _Model.where(id: _id = message[:object_key]).first
        result =
          case result = runnable.run(message[:input])
          when Hash, Array
            JSON.pretty_generate(result)
          else
            result.to_s
          end
        attachment =
          if result.present?
            {
              filename: "#{runnable.name.collectionize}_#{DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S')}.txt",
              contentType: 'text/plain',
              body: result
            }
          else
            nil
          end
        notify(message: "'#{runnable.custom_title}' result" + (result.present? ? '' : ' was empty'),
               type: :notice,
               attachment: attachment,
               skip_notification_level: message[:skip_notification_level])
      else
        fail "#{_Model} with id #{_id} not found"
      end
    end
  end
end
