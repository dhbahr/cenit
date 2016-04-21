module Cenit
  class UserScriptHandler
    class << self

      def deploy_script(user_script)
        bundle_dir = Dir.mktmpdir user_script.name

        proc_file = "Procfile"
        dep_file = "Gemlock"
        script_file = "web.rb"

        proc = "web: ruby web.rb"

        if user_script.language == :Python
          dep_file = "requirements.txt"
          script_file = "web.py"
          proc = "web: python web.py"
        end

        dep_path = "#{bundle_dir}/#{dep_file}"
        proc_path = "#{bundle_dir}/#{proc_file}"
        script_path = "#{bundle_dir}/#{script_file}"

        File.open(dep_path, "w") {|file| file.write(user_script.dependencies)}
        File.open(proc_path, "w") {|file| file.write(proc)}
        File.open(script_path, "w") {|file| file.write(user_script.code)}

        puts "tar cC #{bundle_dir} . | #{ENV['BUILDSTEP']}/buildstep #{user_script.name}"
        `tar cC #{bundle_dir} . | #{ENV['BUILDSTEP']}/buildstep #{user_script.name}`
      end

    end
  end
end