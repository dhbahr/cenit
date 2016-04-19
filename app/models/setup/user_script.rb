module Setup
  class UserScript
    include CenitScoped
    include NamespaceNamed

    BuildInDataType.regist(self).referenced_by(:namespace, :name)

    field :description, type: String
    field :language, type: Symbol
    field :dependencies, type: String
    field :code, type: String

    embeds_many :parameters, class_name: Setup::AlgorithmParameter.to_s, inverse_of: nil
    embeds_many :call_links, class_name: Setup::CallLink.to_s, inverse_of: nil

    validates_format_of :name, with: /\A[a-z]([a-z]|_|\d)*\Z/

    before_save :validate_code
    after_save :bundle_script

    def language_enum
      [:Ruby, :Python]
    end

    def validate_code
      if code.blank?
        errors.add(:code, "can't be blank")
      end
      errors.blank?
    end

    def bundle_script
      script_dir = Dir.mktmpdir name

      proc_file = "Procfile"
      dep_file = "Gemlock"
      script_file = "web.rb"

      proc = "web: ruby web.rb"

      if language == :Python
        dep_file = "requirements.txt"
        script_file = "web.py"
        proc = "web: python web.py"
      end

      dep_path = "#{script_dir}/#{dep_file}"
      proc_path = "#{script_dir}/#{proc_file}"
      script_path = "#{script_dir}/#{script_file}"

      File.open(dep_path, "w") {|file| file.write(dependencies)}
      File.open(proc_path, "w") {|file| file.write(proc)}
      File.open(script_path, "w") {|file| file.write(code)}

      `tar -C #{script_dir} -cvf /tmp/#{name}.tar .`
    end

    def run(input)
      script_dir = "/tmp"
      script_path = "#{script_dir}/#{name}"

      File.open(script_path, "w") {|file| file.write(code)}

      interpreter = "ruby"
      if language == :Python
        interpreter = "python"
      end

      `#{interpreter} #{script_path}`
    end

  end
end