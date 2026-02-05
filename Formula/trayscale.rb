class Trayscale < Formula
  desc "Unofficial GUI interface for the Tailscale daemon"
  homepage "https://github.com/DeedleFake/trayscale"
  url "https://github.com/thormme/trayscale.git",
      tag:      "master"
  license "BSD-3-Clause"
  version "v0.18.5"

  livecheck do
    url "https://github.com/DeedleFake/trayscale"
    regex(/^v?(\d+(?:\.\d+)+)$/i)
    strategy :github_latest
  end

#   bottle do
#     sha256 cellar: :any_skip_relocation, arm64_tahoe:   "89b7991f9aa226c4bc1e8920e1c626e7599af0dacb15d4849e818e61a3efead4"
#     sha256 cellar: :any_skip_relocation, arm64_sequoia: "dd4184c80c37011040d49693434fb6d05adb6f5b89525f2f5e25aaa79e9f7872"
#     sha256 cellar: :any_skip_relocation, arm64_sonoma:  "2c51ed0928285b11e5b8490961a061e4abd4a9ef84a5733f6cd1f04709198224"
#     sha256 cellar: :any_skip_relocation, sonoma:        "c209c4ee26ded785b2893d9e8ec2745fca795b0a872228f64c79e62edbb85f1f"
#     sha256 cellar: :any_skip_relocation, arm64_linux:   "9a029c6d22022602d8e86f7f582d8deaf925a5be90daeacbb9eb2229a3d1a360"
#     sha256 cellar: :any_skip_relocation, x86_64_linux:  "9a0fc1d71206b6ace0526d9c2650abd9da7d139228aeca01a4ec8ed9531ff126"
#   end

  depends_on "go" => :build
  depends_on "libadwaita" => :build
  depends_on "gtk4" => :build
  depends_on "gobject-introspection" => :build
  depends_on "harfbuzz" => :build
  depends_on "appstream" => :build
  depends_on "glib" => :build
  depends_on "cairo" => :build
  depends_on "pango" => :build
  depends_on "gdk-pixbuf" => :build

  # conflicts_with cask: "tailscale-app"

  def install

    metainfo = File.read("dev.deedles.Trayscale.metainfo.xml")
    app_version = metainfo[/<release\s+version="([^"]+)"/, 1] || version

    ldflags = %W[
      -s -w
      -X deedles.dev/trayscale/internal/metadata.version=#{app_version}"
    ]
      
    system "go", "build", *std_go_args(ldflags:), "./cmd/trayscale"

    # Install binary to libexec (actual executable)
    libexec.install "trayscale"

    # Create wrapper script to set up environment
    (bin/"trayscale").write <<~EOS
      #!/bin/bash
      export XDG_DATA_DIRS="#{HOMEBREW_PREFIX}/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
      exec "#{libexec}/trayscale" "$@"
    EOS
    
    # Install GLib schema
    (share/"glib-2.0/schemas").install "dev.deedles.Trayscale.gschema.xml"

  end

#   test do
#     # Basic test that the binary runs
#     assert_match "Usage", shell_output("#{bin}/trayscale --help", 2)
#   end
end