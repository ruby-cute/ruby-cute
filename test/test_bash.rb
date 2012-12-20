
require 'test/unit'
require 'cute/bash'

class TestBash < Test::Unit::TestCase

    def with_bash(cmd = 'bash', &block)
        return Cute::Bash.bash(cmd, &block)
    end

    def assert_status_error(&block)
        throws = false
        begin
            with_bash(&block)
        rescue Cute::Bash::StatusError
            throws = true
        end
        assert_equal throws, true
    end

    def test_files_dirs
        with_bash do
            cd '/'
            assert pwd == '/'
            assert dirs.include?('bin')
            cd 'tmp'
            assert pwd == '/tmp'
            run 'rm -rf /tmp/bash_tests'
            mkdir 'bash_tests'
            cd 'bash_tests'
            assert ls == []
            touch 'file'
            assert ls == [ 'file' ]
            assert ls == files
            mv 'file', 'backup'
            assert ls == [ 'backup' ]
            mkdir 'subdir'
            assert ls.length == 2
            assert dirs == [ 'subdir' ]
            cp 'backup', 'subdir/whatever'
            cd 'subdir'
            assert ls == [ 'whatever' ]
            cd '..'
            assert abspath('subdir/hmmm') == '/tmp/bash_tests/subdir/hmmm'

            f = tmp_file()
            assert exists(f)
            assert get_type(f) == :file
            assert get_type('/var') == :dir
            append_line f, "1st"
            append_lines f, [ "2nd", "3rd" ]
            assert cat(f) == contents(f)
            lines = cat(f)
            assert lines == "1st\n2nd\n3rd\n"
        end
    end

    def test_utils
        with_bash do
            assert (echo 'anybody?') == ("anybody?\n")
            assert (bc '2 + 2 * 2') == '6'
        end
    end

    def test_error
        assert_status_error do
            rm '/'
        end
    end

end
