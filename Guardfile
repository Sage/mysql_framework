# frozen_string_literal: true

# More info at https://github.com/guard/guard#readme
guard :rspec, cmd: 'rspec' do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})                   { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch(%r{^lib/mysql_framework/(.+)\.rb$})   { |m| "spec/lib/mysql_framework/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')                { "spec" }
end
