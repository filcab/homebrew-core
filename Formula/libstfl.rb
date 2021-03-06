class Libstfl < Formula
  desc "Library implementing a curses-based widget set for terminals"
  homepage "http://www.clifford.at/stfl/"
  url "http://www.clifford.at/stfl/stfl-0.24.tar.gz"
  sha256 "d4a7aa181a475aaf8a8914a8ccb2a7ff28919d4c8c0f8a061e17a0c36869c090"
  revision 12

  livecheck do
    url :homepage
    regex(/href=.*?stfl[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  bottle do
    cellar :any
    sha256 "2be12f503697bd427bac888ef5a45672c9fa29a3a3d5952d7d4e1f363ab5d646" => :big_sur
    sha256 "b6ac2ed270bf310230646658cf69b0029d7ef8c44bfb12dbd059e66dee62e148" => :arm64_big_sur
    sha256 "8f01970ef49df0a256cae4e9b487a70b30e34b2958a742f486911a19df5195f3" => :catalina
    sha256 "7ed2e7bb46d76f5c8db0ae28e5adb586d9f1bde981a4e221ec64f8cea8ba9ded" => :mojave
  end

  depends_on "swig" => :build
  depends_on "python@3.9"
  depends_on "ruby"

  uses_from_macos "perl"

  def install
    ENV.prepend_path "PATH", Formula["python@3.9"].opt_libexec/"bin"

    ENV.append "LDLIBS", "-liconv"
    ENV.append "LIBS", "-lncurses -liconv -lruby"

    %w[
      stfl.pc.in
      perl5/Makefile.PL
      ruby/Makefile.snippet
    ].each do |f|
      inreplace f, "ncursesw", "ncurses"
    end

    inreplace "stfl_internals.h", "ncursesw/ncurses.h", "ncurses.h"

    inreplace "Makefile" do |s|
      s.gsub! "ncursesw", "ncurses"
      s.gsub! "-Wl,-soname,$(SONAME)", "-Wl"
      s.gsub! "libstfl.so.$(VERSION)", "libstfl.$(VERSION).dylib"
      s.gsub! "libstfl.so", "libstfl.dylib"
    end

    xy = "3.8"
    python_config = Formula["python@3.9"].opt_libexec/"bin/python-config"

    inreplace "python/Makefile.snippet" do |s|
      # Install into the site-packages in the Cellar (so uninstall works)
      s.change_make_var! "PYTHON_SITEARCH", lib/"python#{xy}/site-packages"
      s.gsub! "lib-dynload/", ""
      s.gsub! "ncursesw", "ncurses"
      s.gsub! "gcc", "gcc -undefined dynamic_lookup #{`#{python_config} --cflags`.chomp}"
      s.gsub! "-lncurses", "-lncurses -liconv"
    end

    # Fails race condition of test:
    #   ImportError: dynamic module does not define init function (init_stfl)
    #   make: *** [python/_stfl.so] Error 1
    ENV.deparallelize

    system "make"

    inreplace "perl5/Makefile", "Network/Library", libexec/"lib/perl5"
    system "make", "install", "prefix=#{prefix}"
  end

  test do
    (testpath/"test.cpp").write <<~EOS
      #include <stfl.h>
      int main() {
        stfl_ipool * pool = stfl_ipool_create("utf-8");
        stfl_ipool_destroy(pool);
        return 0;
      }
    EOS
    system ENV.cxx, "test.cpp", "-L#{lib}", "-lstfl", "-o", "test"
    system "./test"
  end
end
