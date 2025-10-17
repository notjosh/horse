class Horse < Formula
  desc "Display an animated ASCII art carousel of horses"
  homepage "https://github.com/notjosh/manhorse"
  url "https://github.com/notjosh/manhorse/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "b0ae58ce0e0cbcf1293e6f1bffda6c0c3ec02a2334e61b0c3d7887b7211339b9"
  license "MIT"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
    man1.install "man/horse.1"
  end

  test do
    assert_predicate bin/"horse", :exist?
  end
end
