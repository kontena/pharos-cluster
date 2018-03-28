module FixturesDirHelper
  def fixtures_dir(*joinables)
    File.join(*[File.expand_path('../fixtures', __dir__)] + joinables)
  end
  module_function :fixtures_dir
end
