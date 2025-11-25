# frozen_string_literal: true

require "tempfile"
require "mysql-pr"

# MYSQL_USER must have ALL privilege for MYSQL_DATABASE.* and RELOAD privilege for *.*
MYSQL_SERVER   = ENV["MYSQL_SERVER"]   || "127.0.0.1"
MYSQL_USER     = ENV["MYSQL_USER"]     || "root"
MYSQL_PASSWORD = ENV["MYSQL_PASSWORD"] || ""
MYSQL_DATABASE = ENV["MYSQL_DATABASE"] || "test_for_mysql_ruby"
MYSQL_PORT     = ENV["MYSQL_PORT"]     || 3306
MYSQL_SOCKET   = ENV["MYSQL_SOCKET"]

RSpec.describe "MysqlPR::VERSION" do
  it "returns client version" do
    expect(MysqlPR::VERSION).to eq "3.0.0"
  end
end

RSpec.describe "MysqlPR.init" do
  it "returns Mysql object" do
    expect(MysqlPR.init).to be_a MysqlPR
  end
end

RSpec.describe "MysqlPR.real_connect" do
  after { @m.close }

  it "connects to mysqld" do
    @m = MysqlPR.real_connect(MYSQL_SERVER, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, MYSQL_PORT, MYSQL_SOCKET)
    expect(@m).to be_a MysqlPR
  end

  it "flag argument affects" do
    @m = MysqlPR.real_connect(MYSQL_SERVER, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, MYSQL_PORT, MYSQL_SOCKET, MysqlPR::CLIENT_FOUND_ROWS)
    @m.query "create temporary table t (c int)"
    @m.query "insert into t values (123)"
    @m.query "update t set c=123"
    expect(@m.affected_rows).to eq 1
  end
end

RSpec.describe "MysqlPR.connect" do
  after { @m&.close }

  it "connects to mysqld" do
    @m = MysqlPR.connect(MYSQL_SERVER, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, MYSQL_PORT, MYSQL_SOCKET)
    expect(@m).to be_a MysqlPR
  end
end

RSpec.describe "MysqlPR.new" do
  after { @m&.close }

  it "connects to mysqld" do
    @m = MysqlPR.new(MYSQL_SERVER, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, MYSQL_PORT, MYSQL_SOCKET)
    expect(@m).to be_a MysqlPR
  end
end

RSpec.describe "MysqlPR.escape_string" do
  it "escapes special character" do
    expect(MysqlPR.escape_string("abc'def\"ghi\0jkl%mno")).to eq "abc\\'def\\\"ghi\\0jkl%mno"
  end
end

RSpec.describe "MysqlPR.quote" do
  it "escapes special character" do
    expect(MysqlPR.quote("abc'def\"ghi\0jkl%mno")).to eq "abc\\'def\\\"ghi\\0jkl%mno"
  end
end

RSpec.describe "MysqlPR.client_info" do
  it "returns client version as string" do
    expect(MysqlPR.client_info).to eq "5.0.0"
  end
end

RSpec.describe "MysqlPR.get_client_info" do
  it "returns client version as string" do
    expect(MysqlPR.get_client_info).to eq "5.0.0"
  end
end

RSpec.describe "MysqlPR.client_version" do
  it "returns client version as Integer" do
    expect(MysqlPR.client_version).to eq 50000
  end
end

RSpec.describe "MysqlPR.get_client_version" do
  it "returns client version as Integer" do
    expect(MysqlPR.client_version).to eq 50000
  end
end

RSpec.describe "Mysql#real_connect" do
  after { @m&.close }

  it "connects to mysqld" do
    @m = MysqlPR.init
    expect(@m.real_connect(MYSQL_SERVER, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, MYSQL_PORT, MYSQL_SOCKET)).to eq @m
  end
end

RSpec.describe "Mysql#connect" do
  after { @m&.close }

  it "connects to mysqld" do
    @m = MysqlPR.init
    expect(@m.connect(MYSQL_SERVER, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, MYSQL_PORT, MYSQL_SOCKET)).to eq @m
  end
end

RSpec.describe "Mysql#options" do
  before { @m = MysqlPR.init }
  after { @m.close }

  it "INIT_COMMAND: executes query when connecting" do
    expect(@m.options(MysqlPR::INIT_COMMAND, "SET AUTOCOMMIT=0")).to eq @m
    expect(@m.connect(MYSQL_SERVER, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, MYSQL_PORT, MYSQL_SOCKET)).to eq @m
    expect(@m.query("select @@AUTOCOMMIT").fetch_row).to eq ["0"]
  end

  it "OPT_CONNECT_TIMEOUT: sets timeout for connecting" do
    expect(@m.options(MysqlPR::OPT_CONNECT_TIMEOUT, 0.1)).to eq @m
    allow(UNIXSocket).to receive(:new) { sleep 1 }
    allow(TCPSocket).to receive(:new) { sleep 1 }
    expect { @m.connect(MYSQL_SERVER, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, MYSQL_PORT, MYSQL_SOCKET) }.to raise_error MysqlPR::ClientError, "connection timeout"
    expect { @m.connect }.to raise_error MysqlPR::ClientError, "connection timeout"
  end

  it "OPT_LOCAL_INFILE: client can execute LOAD DATA LOCAL INFILE query" do
    tmpf = Tempfile.new "mysql_spec"
    tmpf.puts "123\tabc\n"
    tmpf.close
    expect(@m.options(MysqlPR::OPT_LOCAL_INFILE, true)).to eq @m
    @m.connect(MYSQL_SERVER, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, MYSQL_PORT, MYSQL_SOCKET)
    @m.query("create temporary table t (i int, c char(10))")
    @m.query("load data local infile '#{tmpf.path}' into table t")
    expect(@m.query("select * from t").fetch_row).to eq ["123", "abc"]
  end

  it "OPT_READ_TIMEOUT: sets timeout for reading packet" do
    expect(@m.options(MysqlPR::OPT_READ_TIMEOUT, 10)).to eq @m
  end

  it "OPT_WRITE_TIMEOUT: sets timeout for writing packet" do
    expect(@m.options(MysqlPR::OPT_WRITE_TIMEOUT, 10)).to eq @m
  end

  it "SET_CHARSET_NAME: sets charset for connection" do
    expect(@m.options(MysqlPR::SET_CHARSET_NAME, "utf8")).to eq @m
    @m.connect(MYSQL_SERVER, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, MYSQL_PORT, MYSQL_SOCKET)
    expect(@m.query("select @@character_set_connection").fetch_row).to eq ["utf8"]
  end
end

RSpec.describe "Mysql" do
  before do
    @m = MysqlPR.new(MYSQL_SERVER, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, MYSQL_PORT, MYSQL_SOCKET)
  end

  after do
    @m&.close rescue nil
  end

  describe "#escape_string" do
    it "escapes special character for charset" do
      @m.charset = "cp932"
      expect(@m.escape_string("abc'def\"ghi\0jkl%mno_表".encode("cp932"))).to eq "abc\\'def\\\"ghi\\0jkl%mno_表".encode("cp932")
    end
  end

  describe "#quote" do
    it "is alias of #escape_string" do
      expect(@m.method(:quote)).to eq @m.method(:escape_string)
    end
  end

  describe "#client_info" do
    it "returns client version as string" do
      expect(@m.client_info).to eq "5.0.0"
    end
  end

  describe "#get_client_info" do
    it "returns client version as string" do
      expect(@m.get_client_info).to eq "5.0.0"
    end
  end

  describe "#affected_rows" do
    it "returns number of affected rows" do
      @m.query "create temporary table t (id int)"
      @m.query "insert into t values (1),(2)"
      expect(@m.affected_rows).to eq 2
    end
  end

  describe "#character_set_name" do
    it "returns charset name" do
      m = MysqlPR.init
      m.options MysqlPR::SET_CHARSET_NAME, "cp932"
      m.connect MYSQL_SERVER, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, MYSQL_PORT, MYSQL_SOCKET
      expect(m.character_set_name).to eq "cp932"
      m.close
    end
  end

  describe "#close" do
    it "returns self" do
      expect(@m.close).to eq @m
    end
  end

  describe "#close!" do
    it "returns self" do
      expect(@m.close!).to eq @m
    end
  end

  describe "#errno" do
    it "default value is 0" do
      expect(@m.errno).to eq 0
    end

    it "returns error number of latest error" do
      @m.query("hogehoge") rescue nil
      expect(@m.errno).to eq 1064
    end
  end

  describe "#error" do
    it "returns error message of latest error" do
      @m.query("hogehoge") rescue nil
      expect(@m.error).to eq "You have an error in your SQL syntax; check the manual that corresponds to your MySQL server version for the right syntax to use near 'hogehoge' at line 1"
    end
  end

  describe "#field_count" do
    it "returns number of fields for latest query" do
      @m.query "select 1,2,3"
      expect(@m.field_count).to eq 3
    end
  end

  describe "#client_version" do
    it "returns client version as Integer" do
      expect(@m.client_version).to be_a Integer
    end
  end

  describe "#get_client_version" do
    it "returns client version as Integer" do
      expect(@m.get_client_version).to be_a Integer
    end
  end

  describe "#get_host_info" do
    it "returns connection type as String" do
      if MYSQL_SERVER.nil? || MYSQL_SERVER == "localhost"
        expect(@m.get_host_info).to eq "Localhost via UNIX socket"
      else
        expect(@m.get_host_info).to eq "#{MYSQL_SERVER} via TCP/IP"
      end
    end
  end

  describe "#host_info" do
    it "returns connection type as String" do
      if MYSQL_SERVER.nil? || MYSQL_SERVER == "localhost"
        expect(@m.host_info).to eq "Localhost via UNIX socket"
      else
        expect(@m.host_info).to eq "#{MYSQL_SERVER} via TCP/IP"
      end
    end
  end

  describe "#get_proto_info" do
    it "returns version of connection as Integer" do
      expect(@m.get_proto_info).to eq 10
    end
  end

  describe "#proto_info" do
    it "returns version of connection as Integer" do
      expect(@m.proto_info).to eq 10
    end
  end

  describe "#get_server_info" do
    it "returns server version as String" do
      expect(@m.get_server_info).to match(/\A\d+\.\d+\.\d+/)
    end
  end

  describe "#server_info" do
    it "returns server version as String" do
      expect(@m.server_info).to match(/\A\d+\.\d+\.\d+/)
    end
  end

  describe "#info" do
    it "returns information of latest query" do
      @m.query "create temporary table t (id int)"
      @m.query "insert into t values (1),(2),(3)"
      expect(@m.info).to eq "Records: 3  Duplicates: 0  Warnings: 0"
    end
  end

  describe "#insert_id" do
    it "returns latest auto_increment value" do
      @m.query "create temporary table t (id int auto_increment, unique (id))"
      @m.query "insert into t values (0)"
      expect(@m.insert_id).to eq 1
      @m.query "alter table t auto_increment=1234"
      @m.query "insert into t values (0)"
      expect(@m.insert_id).to eq 1234
    end
  end

  describe "#kill" do
    it "returns self" do
      expect(@m.kill(@m.thread_id)).to eq @m
    end

    it "kills specified connection" do
      m = MysqlPR.new(MYSQL_SERVER, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, MYSQL_PORT, MYSQL_SOCKET)
      expect(m.list_processes.map(&:first)).to include @m.thread_id.to_s
      m.close
    end
  end

  describe "#list_dbs" do
    it "returns database list" do
      ret = @m.list_dbs
      expect(ret).to be_a Array
      expect(ret).to include MYSQL_DATABASE
    end

    it "with pattern returns databases that matches pattern" do
      expect(@m.list_dbs("info%")).to include "information_schema"
    end
  end

  describe "#list_fields" do
    before do
      @m.query "create temporary table t (i int, c char(10), d date)"
    end

    it "returns result set that contains information of fields" do
      ret = @m.list_fields("t")
      expect(ret).to be_a MysqlPR::Result
      expect(ret.num_rows).to eq 0
      expect(ret.fetch_fields.map(&:name)).to eq ["i", "c", "d"]
    end

    it "with pattern returns result set that contains information of fields that matches pattern" do
      ret = @m.list_fields("t", "i")
      expect(ret).to be_a MysqlPR::Result
      expect(ret.num_rows).to eq 0
      expect(ret.fetch_fields.map(&:name)).to eq ["i"]
    end
  end

  describe "#list_processes" do
    it "returns result set that contains information of all connections" do
      ret = @m.list_processes
      expect(ret).to be_a MysqlPR::Result
      expect(ret.find { |r| r[0].to_i == @m.thread_id }[4]).to eq "Processlist"
    end
  end

  describe "#list_tables" do
    before { @m.query "create table test_mysql_list_tables (id int)" }
    after { @m.query "drop table test_mysql_list_tables" }

    it "returns table list" do
      ret = @m.list_tables
      expect(ret).to be_a Array
      expect(ret).to include "test_mysql_list_tables"
    end

    it "with pattern returns lists that matches pattern" do
      ret = @m.list_tables '%mysql\_list\_t%'
      expect(ret).to include "test_mysql_list_tables"
    end
  end

  describe "#ping" do
    it "returns self" do
      expect(@m.ping).to eq @m
    end
  end

  describe "#query" do
    it "returns MysqlPR::Result if query returns results" do
      expect(@m.query("select 123")).to be_a MysqlPR::Result
    end

    it "returns nil if query returns no results" do
      expect(@m.query("set @hoge:=123")).to be_nil
    end

    it "returns self if query_with_result is false" do
      @m.query_with_result = false
      expect(@m.query("select 123")).to eq @m
      @m.store_result
      expect(@m.query("set @hoge:=123")).to eq @m
    end
  end

  describe "#real_query" do
    it "is same as #query" do
      expect(@m.real_query("select 123")).to be_a MysqlPR::Result
    end
  end

  describe "#refresh" do
    it "returns self" do
      expect(@m.refresh(MysqlPR::REFRESH_HOSTS)).to eq @m
    end
  end

  describe "#reload" do
    it "returns self" do
      expect(@m.reload).to eq @m
    end
  end

  describe "#select_db" do
    it "changes default database" do
      @m.select_db "information_schema"
      expect(@m.query("select database()").fetch_row.first).to eq "information_schema"
    end
  end

  describe "#stat" do
    it "returns server status" do
      expect(@m.stat).to match(/\AUptime: \d+  Threads: \d+  Questions: \d+  Slow queries: \d+  Opens: \d+  Flush tables: \d+  Open tables: \d+  Queries per second avg: \d+\.\d+\z/)
    end
  end

  describe "#store_result" do
    it "returns MysqlPR::Result" do
      @m.query_with_result = false
      @m.query "select 1,2,3"
      ret = @m.store_result
      expect(ret).to be_a MysqlPR::Result
      expect(ret.fetch_row).to eq ["1", "2", "3"]
    end

    it "raises error when no query" do
      expect { @m.store_result }.to raise_error MysqlPR::Error
    end

    it "raises error when query does not return results" do
      @m.query "set @hoge:=123"
      expect { @m.store_result }.to raise_error MysqlPR::Error
    end
  end

  describe "#thread_id" do
    it "returns thread id as Integer" do
      expect(@m.thread_id).to be_a Integer
    end
  end

  describe "#use_result" do
    it "returns MysqlPR::Result" do
      @m.query_with_result = false
      @m.query "select 1,2,3"
      ret = @m.use_result
      expect(ret).to be_a MysqlPR::Result
      expect(ret.fetch_row).to eq ["1", "2", "3"]
    end

    it "raises error when no query" do
      expect { @m.use_result }.to raise_error MysqlPR::Error
    end

    it "raises error when query does not return results" do
      @m.query "set @hoge:=123"
      expect { @m.use_result }.to raise_error MysqlPR::Error
    end
  end

  describe "#get_server_version" do
    it "returns server version as Integer" do
      expect(@m.get_server_version).to be_a Integer
    end
  end

  describe "#server_version" do
    it "returns server version as Integer" do
      expect(@m.server_version).to be_a Integer
    end
  end

  describe "#warning_count" do
    it "default value is zero" do
      expect(@m.warning_count).to eq 0
    end

    it "returns number of warnings" do
      @m.query "create temporary table t (i tinyint)"
      @m.query "insert into t values (1234567)"
      expect(@m.warning_count).to eq 1
    end
  end

  describe "#commit" do
    it "returns self" do
      expect(@m.commit).to eq @m
    end
  end

  describe "#rollback" do
    it "returns self" do
      expect(@m.rollback).to eq @m
    end
  end

  describe "#autocommit" do
    it "returns self" do
      expect(@m.autocommit(true)).to eq @m
    end

    it "changes auto-commit mode" do
      @m.autocommit(true)
      expect(@m.query("select @@autocommit").fetch_row).to eq ["1"]
      @m.autocommit(false)
      expect(@m.query("select @@autocommit").fetch_row).to eq ["0"]
    end
  end

  describe "#set_server_option" do
    it "returns self" do
      expect(@m.set_server_option(MysqlPR::OPTION_MULTI_STATEMENTS_ON)).to eq @m
    end
  end

  describe "#sqlstate" do
    it 'default value is "00000"' do
      expect(@m.sqlstate).to eq "00000"
    end

    it "returns sqlstate code" do
      expect { @m.query("hoge") }.to raise_error(MysqlPR::Error)
      expect(@m.sqlstate).to eq "42000"
    end
  end

  describe "#query_with_result" do
    it "default value is true" do
      expect(@m.query_with_result).to eq true
    end

    it "can set value" do
      expect(@m.query_with_result = true).to eq true
      expect(@m.query_with_result).to eq true
      expect(@m.query_with_result = false).to eq false
      expect(@m.query_with_result).to eq false
    end
  end

  describe "#query_with_result is false" do
    it "Mysql#query returns self and Mysql#store_result returns result set" do
      @m.query_with_result = false
      expect(@m.query("select 1,2,3")).to eq @m
      res = @m.store_result
      expect(res.fetch_row).to eq ["1", "2", "3"]
    end
  end

  describe "#query with block" do
    it "returns self" do
      expect(@m.query("select 1") {}).to eq @m
    end

    it "evaluates block with MysqlPR::Result" do
      @m.query("select 1") { |res| expect(res).to be_a MysqlPR::Result }
    end

    it "evaluates block multiple times if multiple query is specified" do
      @m.set_server_option MysqlPR::OPTION_MULTI_STATEMENTS_ON
      cnt = 0
      expected = [["1"], ["2"]]
      result = @m.query("select 1; select 2") do |res|
        expect(res.fetch_row).to eq expected.shift
        cnt += 1
      end
      expect(result).to eq @m
      expect(cnt).to eq 2
    end

    it "evaluates block only when query has result" do
      @m.set_server_option MysqlPR::OPTION_MULTI_STATEMENTS_ON
      cnt = 0
      expected = [["1"], ["2"]]
      result = @m.query("select 1; set @hoge:=1; select 2") do |res|
        expect(res.fetch_row).to eq expected.shift
        cnt += 1
      end
      expect(result).to eq @m
      expect(cnt).to eq 2
    end
  end
end

RSpec.describe "multiple statement query:" do
  before do
    @m = MysqlPR.new(MYSQL_SERVER, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, MYSQL_PORT, MYSQL_SOCKET)
    @m.set_server_option(MysqlPR::OPTION_MULTI_STATEMENTS_ON)
  end

  after { @m&.close }

  it "handles multiple statements in sequence" do
    res = @m.query "select 1,2; select 3,4,5"

    # First query results
    expect(res.entries).to eq [["1", "2"]]

    # More results available
    expect(@m.more_results).to eq true
    expect(@m.more_results?).to eq true

    # Move to next result
    expect(@m.next_result).to eq true

    # Second query results
    res2 = @m.store_result
    expect(res2.entries).to eq [["3", "4", "5"]]

    # No more results
    expect(@m.more_results).to eq false
    expect(@m.more_results?).to eq false
    expect(@m.next_result).to eq false
  end
end

RSpec.describe "MysqlPR::Result" do
  before do
    @m = MysqlPR.new(MYSQL_SERVER, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, MYSQL_PORT, MYSQL_SOCKET)
    @m.charset = "latin1"
    @m.query 'create temporary table t (id int, str char(10), primary key (id))'
    @m.query "insert into t values (1,'abc'),(2,'defg'),(3,'hi'),(4,null)"
    @res = @m.query "select * from t"
  end

  after { @m&.close }

  it "#data_seek sets position of current record" do
    expect(@res.fetch_row).to eq ["1", "abc"]
    expect(@res.fetch_row).to eq ["2", "defg"]
    expect(@res.fetch_row).to eq ["3", "hi"]
    @res.data_seek 1
    expect(@res.fetch_row).to eq ["2", "defg"]
  end

  it "#fetch_field returns current field" do
    f = @res.fetch_field
    expect(f.name).to eq "id"
    expect(f.table).to eq "t"
    expect(f.def).to be_nil
    expect(f.type).to eq MysqlPR::Field::TYPE_LONG
    expect(f.length).to eq 11
    expect(f.max_length).to eq 1
    # Check that expected flags are set (MySQL 8.0+ may add additional flags)
    expected_flags = MysqlPR::Field::NUM_FLAG | MysqlPR::Field::PRI_KEY_FLAG | MysqlPR::Field::PART_KEY_FLAG | MysqlPR::Field::NOT_NULL_FLAG
    expect(f.flags & expected_flags).to eq expected_flags
    expect(f.decimals).to eq 0

    f = @res.fetch_field
    expect(f.name).to eq "str"
    expect(f.table).to eq "t"
    expect(f.def).to be_nil
    expect(f.type).to eq MysqlPR::Field::TYPE_STRING
    expect(f.length).to eq 10
    expect(f.max_length).to eq 4
    expect(f.flags & MysqlPR::Field::NOT_NULL_FLAG).to eq 0
    expect(f.decimals).to eq 0

    expect(@res.fetch_field).to be_nil
  end

  it "#fetch_fields returns array of fields" do
    ret = @res.fetch_fields
    expect(ret.size).to eq 2
    expect(ret[0].name).to eq "id"
    expect(ret[1].name).to eq "str"
  end

  it "#fetch_field_direct returns field" do
    f = @res.fetch_field_direct 0
    expect(f.name).to eq "id"
    f = @res.fetch_field_direct 1
    expect(f.name).to eq "str"
    expect { @res.fetch_field_direct(-1) }.to raise_error MysqlPR::ClientError, "invalid argument: -1"
    expect { @res.fetch_field_direct 2 }.to raise_error MysqlPR::ClientError, "invalid argument: 2"
  end

  it "#fetch_lengths returns array of length of field data" do
    expect(@res.fetch_lengths).to be_nil
    @res.fetch_row
    expect(@res.fetch_lengths).to eq [1, 3]
    @res.fetch_row
    expect(@res.fetch_lengths).to eq [1, 4]
    @res.fetch_row
    expect(@res.fetch_lengths).to eq [1, 2]
    @res.fetch_row
    expect(@res.fetch_lengths).to eq [1, 0]
    @res.fetch_row
    expect(@res.fetch_lengths).to be_nil
  end

  it "#fetch_row returns one record as array for current record" do
    expect(@res.fetch_row).to eq ["1", "abc"]
    expect(@res.fetch_row).to eq ["2", "defg"]
    expect(@res.fetch_row).to eq ["3", "hi"]
    expect(@res.fetch_row).to eq ["4", nil]
    expect(@res.fetch_row).to be_nil
  end

  it "#fetch_hash returns one record as hash for current record" do
    expect(@res.fetch_hash).to eq({ "id" => "1", "str" => "abc" })
    expect(@res.fetch_hash).to eq({ "id" => "2", "str" => "defg" })
    expect(@res.fetch_hash).to eq({ "id" => "3", "str" => "hi" })
    expect(@res.fetch_hash).to eq({ "id" => "4", "str" => nil })
    expect(@res.fetch_hash).to be_nil
  end

  it "#fetch_hash(true) returns with table name" do
    expect(@res.fetch_hash(true)).to eq({ "t.id" => "1", "t.str" => "abc" })
    expect(@res.fetch_hash(true)).to eq({ "t.id" => "2", "t.str" => "defg" })
    expect(@res.fetch_hash(true)).to eq({ "t.id" => "3", "t.str" => "hi" })
    expect(@res.fetch_hash(true)).to eq({ "t.id" => "4", "t.str" => nil })
    expect(@res.fetch_hash(true)).to be_nil
  end

  it "#num_fields returns number of fields" do
    expect(@res.num_fields).to eq 2
  end

  it "#num_rows returns number of records" do
    expect(@res.num_rows).to eq 4
  end

  it "#each iterates block with a record" do
    expected = [["1", "abc"], ["2", "defg"], ["3", "hi"], ["4", nil]]
    @res.each do |a|
      expect(a).to eq expected.shift
    end
  end

  it "#each_hash iterates block with a hash" do
    expected = [{ "id" => "1", "str" => "abc" }, { "id" => "2", "str" => "defg" }, { "id" => "3", "str" => "hi" }, { "id" => "4", "str" => nil }]
    @res.each_hash do |a|
      expect(a).to eq expected.shift
    end
  end

  it "#each_hash(true): hash key has table name" do
    expected = [{ "t.id" => "1", "t.str" => "abc" }, { "t.id" => "2", "t.str" => "defg" }, { "t.id" => "3", "t.str" => "hi" }, { "t.id" => "4", "t.str" => nil }]
    @res.each_hash(true) do |a|
      expect(a).to eq expected.shift
    end
  end

  it "#row_tell returns position of current record, #row_seek sets position of current record" do
    expect(@res.fetch_row).to eq ["1", "abc"]
    pos = @res.row_tell
    expect(@res.fetch_row).to eq ["2", "defg"]
    expect(@res.fetch_row).to eq ["3", "hi"]
    @res.row_seek pos
    expect(@res.fetch_row).to eq ["2", "defg"]
  end

  it "#field_tell returns position of current field, #field_seek sets position of current field" do
    expect(@res.field_tell).to eq 0
    @res.fetch_field
    expect(@res.field_tell).to eq 1
    @res.fetch_field
    expect(@res.field_tell).to eq 2
    @res.field_seek 1
    expect(@res.field_tell).to eq 1
  end

  it "#free returns nil" do
    expect(@res.free).to be_nil
  end
end

RSpec.describe "MysqlPR::Field" do
  before do
    @m = MysqlPR.new(MYSQL_SERVER, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, MYSQL_PORT, MYSQL_SOCKET)
    @m.charset = "latin1"
    @m.query 'create temporary table t (id int default 0, str char(10), primary key (id))'
    @m.query "insert into t values (1,'abc'),(2,'defg'),(3,'hi'),(4,null)"
    @res = @m.query "select * from t"
  end

  after { @m&.close }

  it "#name is name of field" do
    expect(@res.fetch_field.name).to eq "id"
  end

  it "#table is name of table for field" do
    expect(@res.fetch_field.table).to eq "t"
  end

  it "#def for result set is null" do
    expect(@res.fetch_field.def).to be_nil
  end

  it "#def for field information is default value" do
    expect(@m.list_fields("t").fetch_field.def).to eq "0"
  end

  it "#type is type of field as Integer" do
    expect(@res.fetch_field.type).to eq MysqlPR::Field::TYPE_LONG
    expect(@res.fetch_field.type).to eq MysqlPR::Field::TYPE_STRING
  end

  it "#length is length of field" do
    expect(@res.fetch_field.length).to eq 11
    expect(@res.fetch_field.length).to eq 10
  end

  it "#max_length is maximum length of field value" do
    expect(@res.fetch_field.max_length).to eq 1
    expect(@res.fetch_field.max_length).to eq 4
  end

  it "#flags is flag of field as Integer" do
    expect(@res.fetch_field.flags).to eq MysqlPR::Field::NUM_FLAG | MysqlPR::Field::PRI_KEY_FLAG | MysqlPR::Field::PART_KEY_FLAG | MysqlPR::Field::NOT_NULL_FLAG
    expect(@res.fetch_field.flags).to eq 0
  end

  it "#decimals is number of decimal digits" do
    expect(@m.query("select 1.23").fetch_field.decimals).to eq 2
  end

  it "#hash returns field as hash" do
    expect(@res.fetch_field.hash).to eq({
      "name"       => "id",
      "table"      => "t",
      "def"        => nil,
      "type"       => MysqlPR::Field::TYPE_LONG,
      "length"     => 11,
      "max_length" => 1,
      "flags"      => MysqlPR::Field::NUM_FLAG | MysqlPR::Field::PRI_KEY_FLAG | MysqlPR::Field::PART_KEY_FLAG | MysqlPR::Field::NOT_NULL_FLAG,
      "decimals"   => 0,
    })
    expect(@res.fetch_field.hash).to eq({
      "name"       => "str",
      "table"      => "t",
      "def"        => nil,
      "type"       => MysqlPR::Field::TYPE_STRING,
      "length"     => 10,
      "max_length" => 4,
      "flags"      => 0,
      "decimals"   => 0,
    })
  end

  it '#inspect returns "#<MysqlPR::Field:name>"' do
    expect(@res.fetch_field.inspect).to eq "#<MysqlPR::Field:id>"
    expect(@res.fetch_field.inspect).to eq "#<MysqlPR::Field:str>"
  end

  it "#is_num? returns true if the field is numeric" do
    expect(@res.fetch_field.is_num?).to eq true
    expect(@res.fetch_field.is_num?).to eq false
  end

  it "#is_not_null? returns true if the field is not null" do
    expect(@res.fetch_field.is_not_null?).to eq true
    expect(@res.fetch_field.is_not_null?).to eq false
  end

  it "#is_pri_key? returns true if the field is primary key" do
    expect(@res.fetch_field.is_pri_key?).to eq true
    expect(@res.fetch_field.is_pri_key?).to eq false
  end
end

RSpec.describe "create MysqlPR::Stmt object:" do
  before { @m = MysqlPR.new(MYSQL_SERVER, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, MYSQL_PORT, MYSQL_SOCKET) }
  after { @m&.close }

  it "Mysql#stmt_init returns MysqlPR::Stmt object" do
    expect(@m.stmt_init).to be_a MysqlPR::Stmt
  end

  it "Mysql#prepare returns MysqlPR::Stmt object" do
    expect(@m.prepare("select 1")).to be_a MysqlPR::Stmt
  end
end

RSpec.describe "MysqlPR::Stmt" do
  before do
    @m = MysqlPR.new(MYSQL_SERVER, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, MYSQL_PORT, MYSQL_SOCKET)
    @s = @m.stmt_init
  end

  after do
    @s&.close rescue nil
    @m&.close
  end

  it "#affected_rows returns number of affected records" do
    @m.query "create temporary table t (i int, c char(10))"
    @s.prepare "insert into t values (?,?)"
    @s.execute 1, "hoge"
    expect(@s.affected_rows).to eq 1
    @s.execute 2, "hoge"
    @s.execute 3, "hoge"
    @s.prepare "update t set c=?"
    @s.execute "fuga"
    expect(@s.affected_rows).to eq 3
  end

  describe "#bind_result" do
    before do
      @m.query "create temporary table t (i int, c char(10), d double, t datetime)"
      @m.query "insert into t values (123,'9abcdefg',1.2345,20091208100446)"
      @s.prepare "select * from t"
    end

    it "(nil) makes result format to be standard value" do
      @s.bind_result nil, nil, nil, nil
      @s.execute
      expect(@s.fetch).to eq [123, "9abcdefg", 1.2345, MysqlPR::Time.new(2009, 12, 8, 10, 4, 46)]
    end

    it "(Numeric) makes result format to be Integer value" do
      @s.bind_result Numeric, Numeric, Numeric, Numeric
      @s.execute
      expect(@s.fetch).to eq [123, 9, 1, 20091208100446]
    end

    it "(Integer) makes result format to be Integer value" do
      @s.bind_result Integer, Integer, Integer, Integer
      @s.execute
      expect(@s.fetch).to eq [123, 9, 1, 20091208100446]
    end

    it "(String) makes result format to be String value" do
      @s.bind_result String, String, String, String
      @s.execute
      expect(@s.fetch).to eq ["123", "9abcdefg", "1.2345", "2009-12-08 10:04:46"]
    end

    it "(Float) makes result format to be Float value" do
      @s.bind_result Float, Float, Float, Float
      @s.execute
      expect(@s.fetch).to eq [123.0, 9.0, 1.2345, 20091208100446.0]
    end

    it "(MysqlPR::Time) makes result format to be MysqlPR::Time value" do
      @s.bind_result MysqlPR::Time, MysqlPR::Time, MysqlPR::Time, MysqlPR::Time
      @s.execute
      expect(@s.fetch).to eq [MysqlPR::Time.new(2000, 1, 23), MysqlPR::Time.new, MysqlPR::Time.new, MysqlPR::Time.new(2009, 12, 8, 10, 4, 46)]
    end

    it "(invalid) raises error" do
      expect { @s.bind_result(Time, nil, nil, nil) }.to raise_error(TypeError)
    end

    it "with mismatch argument count raises error" do
      expect { @s.bind_result(nil) }.to raise_error(MysqlPR::ClientError, "bind_result: result value count(4) != number of argument(1)")
    end
  end

  it "#close returns nil" do
    expect(@s.close).to be_nil
  end

  it "#data_seek sets position of current record" do
    @m.query "create temporary table t (i int)"
    @m.query "insert into t values (0),(1),(2),(3),(4),(5),(6)"
    @s.prepare "select i from t"
    @s.execute
    expect(@s.fetch).to eq [0]
    expect(@s.fetch).to eq [1]
    expect(@s.fetch).to eq [2]
    @s.data_seek 5
    expect(@s.fetch).to eq [5]
    @s.data_seek 1
    expect(@s.fetch).to eq [1]
  end

  it "#each iterates block with a record" do
    @m.query "create temporary table t (i int, c char(255), d datetime)"
    @m.query "insert into t values (1,'abc','19701224235905'),(2,'def','21120903123456'),(3,'123',null)"
    @s.prepare "select * from t"
    @s.execute
    expected = [
      [1, "abc", MysqlPR::Time.new(1970, 12, 24, 23, 59, 5)],
      [2, "def", MysqlPR::Time.new(2112, 9, 3, 12, 34, 56)],
      [3, "123", nil],
    ]
    @s.each do |a|
      expect(a).to eq expected.shift
    end
  end

  it "#execute returns self" do
    @s.prepare "select 1"
    expect(@s.execute).to eq @s
  end

  it "#execute passes arguments to query" do
    @m.query "create temporary table t (i int)"
    @s.prepare "insert into t values (?)"
    @s.execute 123
    @s.execute "456"
    expect(@m.query("select * from t").entries).to eq [["123"], ["456"]]
  end

  it "#execute with various arguments" do
    @m.query "create temporary table t (i int, c char(255), t timestamp)"
    @s.prepare "insert into t values (?,?,?)"
    @s.execute 123, "hoge", Time.local(2009, 12, 8, 19, 56, 21)
    expect(@m.query("select * from t").fetch_row).to eq ["123", "hoge", "2009-12-08 19:56:21"]
  end

  it "#execute with arguments that is invalid count raises error" do
    @s.prepare "select ?"
    expect { @s.execute 123, 456 }.to raise_error(MysqlPR::ClientError, "parameter count mismatch")
  end

  it "#execute with huge value" do
    [30, 31, 32, 62, 63].each do |i|
      expect(@m.prepare("select cast(? as signed)").execute(2**i - 1).fetch).to eq [2**i - 1]
      expect(@m.prepare("select cast(? as signed)").execute(-(2**i)).fetch).to eq [-(2**i)]
    end
  end

  it "#fetch returns result-record" do
    @s.prepare 'select 123, "abc", null'
    @s.execute
    expect(@s.fetch).to eq [123, "abc", nil]
  end

  it "#fetch bit column (8bit)" do
    @m.query "create temporary table t (i bit(8))"
    @m.query "insert into t values (0),(-1),(127),(-128),(255),(-255),(256)"
    @s.prepare "select i from t"
    @s.execute
    expect(@s.entries).to eq [
      ["\x00".b],
      ["\xff".b],
      ["\x7f".b],
      ["\xff".b],
      ["\xff".b],
      ["\xff".b],
      ["\xff".b],
    ]
  end

  it "#fetch bit column (64bit)" do
    @m.query "create temporary table t (i bit(64))"
    @m.query "insert into t values (0),(-1),(4294967296),(18446744073709551615),(18446744073709551616)"
    @s.prepare "select i from t"
    @s.execute
    expect(@s.entries).to eq [
      ["\x00\x00\x00\x00\x00\x00\x00\x00".b],
      ["\xff\xff\xff\xff\xff\xff\xff\xff".b],
      ["\x00\x00\x00\x01\x00\x00\x00\x00".b],
      ["\xff\xff\xff\xff\xff\xff\xff\xff".b],
      ["\xff\xff\xff\xff\xff\xff\xff\xff".b],
    ]
  end

  it "#fetch tinyint column" do
    @m.query "create temporary table t (i tinyint)"
    @m.query "insert into t values (0),(-1),(127),(-128),(255),(-255)"
    @s.prepare "select i from t"
    @s.execute
    expect(@s.entries).to eq [[0], [-1], [127], [-128], [127], [-128]]
  end

  it "#fetch tinyint unsigned column" do
    @m.query "create temporary table t (i tinyint unsigned)"
    @m.query "insert into t values (0),(-1),(127),(-128),(255),(-255),(256)"
    @s.prepare "select i from t"
    @s.execute
    expect(@s.entries).to eq [[0], [0], [127], [0], [255], [0], [255]]
  end

  it "#field_count" do
    @s.prepare "select 1,2,3"
    expect(@s.field_count).to eq 3
    @s.prepare "set @a=1"
    expect(@s.field_count).to eq 0
  end

  it "#free_result" do
    @s.free_result
    @s.prepare "select 1,2,3"
    @s.execute
    @s.free_result
  end

  it "#insert_id" do
    @m.query "create temporary table t (i int auto_increment, unique(i))"
    @s.prepare "insert into t values (0)"
    @s.execute
    expect(@s.insert_id).to eq 1
    @s.execute
    expect(@s.insert_id).to eq 2
  end

  it "#num_rows" do
    @m.query "create temporary table t (i int)"
    @m.query "insert into t values (1),(2),(3),(4)"
    @s.prepare "select * from t"
    @s.execute
    expect(@s.num_rows).to eq 4
  end

  it "#param_count" do
    @m.query "create temporary table t (a int, b int, c int)"
    @s.prepare "select * from t"
    expect(@s.param_count).to eq 0
    @s.prepare "insert into t values (?,?,?)"
    expect(@s.param_count).to eq 3
  end

  it "#prepare" do
    expect(@s.prepare("select 1")).to be_a MysqlPR::Stmt
    expect { @s.prepare "invalid syntax" }.to raise_error MysqlPR::ParseError
  end

  it "#prepare returns self" do
    expect(@s.prepare("select 1")).to eq @s
  end

  it "#prepare with invalid query raises error" do
    expect { @s.prepare "invalid query" }.to raise_error MysqlPR::ParseError
  end

  it "#result_metadata" do
    @s.prepare "select 1 foo, 2 bar"
    f = @s.result_metadata.fetch_fields
    expect(f[0].name).to eq "foo"
    expect(f[1].name).to eq "bar"
  end

  it "#result_metadata for no data" do
    @s.prepare "set @a=1"
    expect(@s.result_metadata).to be_nil
  end

  it "#row_seek and #row_tell" do
    @m.query "create temporary table t (i int)"
    @m.query "insert into t values (0),(1),(2),(3),(4)"
    @s.prepare "select * from t"
    @s.execute
    row0 = @s.row_tell
    expect(@s.fetch).to eq [0]
    expect(@s.fetch).to eq [1]
    row2 = @s.row_seek row0
    expect(@s.fetch).to eq [0]
    @s.row_seek row2
    expect(@s.fetch).to eq [2]
  end

  it "#sqlstate" do
    @s.prepare "select 1"
    expect(@s.sqlstate).to eq "00000"
    expect { @s.prepare "hogehoge" }.to raise_error MysqlPR::ParseError
    expect(@s.sqlstate).to eq "42000"
  end
end

RSpec.describe "MysqlPR::Error" do
  before do
    m = MysqlPR.connect(MYSQL_SERVER, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, MYSQL_PORT, MYSQL_SOCKET)
    begin
      m.query("hogehoge")
    rescue => e
      @e = e
    end
    m.close
  end

  it "#error is error message" do
    expect(@e.error).to eq "You have an error in your SQL syntax; check the manual that corresponds to your MySQL server version for the right syntax to use near 'hogehoge' at line 1"
  end

  it "#errno is error number" do
    expect(@e.errno).to eq 1064
  end

  it "#sqlstate is sqlstate value as String" do
    expect(@e.sqlstate).to eq "42000"
  end
end
