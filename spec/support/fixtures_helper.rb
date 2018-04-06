module FixturesHelper
  FIXTURES_PATH = File.expand_path('../fixtures', __dir__)

  def fixtures_dir(*joinables)
    File.join(*[FIXTURES_PATH] + joinables)
  end

  def fixture(file)
    IO.read(fixtures_dir(file))
  end
end