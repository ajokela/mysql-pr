# frozen_string_literal: true

# Copyright (C) 2008-2012 TOMITA Masahiro
# mailto:tommy@tmtm.org

# MySQL connection class.
# @example
#  my = MysqlPR.connect('hostname', 'user', 'password', 'dbname')
#  res = my.query 'select col1,col2 from tbl where id=123'
#  res.each do |c1, c2|
#    p c1, c2
#  end
class MysqlPR
  require "mysql-pr/version"
  require "mysql-pr/constants"
  require "mysql-pr/error"
  require "mysql-pr/charset"
  require "mysql-pr/protocol"
  require "mysql-pr/packet"

  MYSQL_UNIX_PORT = "/tmp/mysql.sock"
  MYSQL_TCP_PORT  = 3306

  # @return [MysqlPR::Charset] character set of MySQL connection
  attr_reader :charset

  # @return [MysqlPR::Protocol] protocol handler
  attr_reader :protocol

  # @return [Boolean] if true, {#query} returns {MysqlPR::Result}
  attr_accessor :query_with_result

  class << self
    # Make MysqlPR object without connecting.
    # @return [MysqlPR]
    def init
      my = allocate
      my.send(:initialize)
      my
    end

    # Make MysqlPR object and connect to mysqld.
    # @param args same as arguments for {#connect}
    # @return [MysqlPR]
    def new(*args)
      my = init
      my.connect(*args)
    end

    alias real_connect new
    alias connect new

    # Escape special character in string.
    # @param [String] str
    # @return [String]
    def escape_string(str)
      str.gsub(/[\0\n\r\\\'\"\x1a]/) do |s|
        case s
        when "\0" then "\\0"
        when "\n" then "\\n"
        when "\r" then "\\r"
        when "\x1a" then "\\Z"
        else "\\#{s}"
        end
      end
    end
    alias quote escape_string

    # @return [String] client version (dummy for MySQL/Ruby compatibility)
    def client_info
      "5.0.0"
    end
    alias get_client_info client_info

    # @return [Integer] client version (dummy for MySQL/Ruby compatibility)
    def client_version
      50000
    end
    alias get_client_version client_version
  end

  def initialize
    @fields = nil
    @protocol = nil
    @charset = nil
    @connect_timeout = nil
    @read_timeout = nil
    @write_timeout = nil
    @init_command = nil
    @sqlstate = "00000"
    @query_with_result = true
    @host_info = nil
    @last_error = nil
    @result_exist = false
    @local_infile = nil
    @ssl_options = nil
  end

  # Connect to mysqld.
  # @param [String, nil] host hostname mysqld running
  # @param [String, nil] user username to connect to mysqld
  # @param [String, nil] passwd password to connect to mysqld
  # @param [String, nil] db initial database name
  # @param [Integer, nil] port port number (used if host is not 'localhost' or nil)
  # @param [String, nil] socket socket file name (used if host is 'localhost' or nil)
  # @param [Integer] flag connection flag. MysqlPR::CLIENT_* ORed
  # @return [MysqlPR] self
  def connect(host = nil, user = nil, passwd = nil, db = nil, port = nil, socket = nil, flag = 0)
    if (flag & CLIENT_COMPRESS) != 0
      warn "unsupported flag: CLIENT_COMPRESS"
      flag &= ~CLIENT_COMPRESS
    end
    @protocol = Protocol.new(host, port, socket, @connect_timeout, @read_timeout, @write_timeout, @ssl_options)
    @protocol.authenticate(user, passwd, db, (@local_infile ? CLIENT_LOCAL_FILES : 0) | flag, @charset)
    @charset ||= @protocol.charset
    @host_info = (host.nil? || host == "localhost") ? "Localhost via UNIX socket" : "#{host} via TCP/IP"
    query(@init_command) if @init_command
    self
  end
  alias real_connect connect

  # Disconnect from mysql.
  # @return [MysqlPR] self
  def close
    if @protocol
      @protocol.quit_command
      @protocol = nil
    end
    self
  end

  # Disconnect from mysql without QUIT packet.
  # @return [MysqlPR] self
  def close!
    if @protocol
      @protocol.close
      @protocol = nil
    end
    self
  end

  # Set option for connection.
  #
  # Available options:
  #   MysqlPR::INIT_COMMAND, MysqlPR::OPT_CONNECT_TIMEOUT, MysqlPR::OPT_READ_TIMEOUT,
  #   MysqlPR::OPT_WRITE_TIMEOUT, MysqlPR::SET_CHARSET_NAME
  # @param [Integer] opt option
  # @param [Object] value option value that depends on opt
  # @return [MysqlPR] self
  def options(opt, value = nil)
    case opt
    when MysqlPR::INIT_COMMAND
      @init_command = value.to_s
    when MysqlPR::OPT_CONNECT_TIMEOUT
      @connect_timeout = value
    when MysqlPR::OPT_LOCAL_INFILE
      @local_infile = value
    when MysqlPR::OPT_READ_TIMEOUT
      @read_timeout = value.to_i
    when MysqlPR::OPT_WRITE_TIMEOUT
      @write_timeout = value.to_i
    when MysqlPR::SET_CHARSET_NAME
      @charset = Charset.by_name(value.to_s)
    else
      warn "option not implemented: #{opt}"
    end
    self
  end

  # Configure SSL options for the connection.
  # Must be called before connect.
  # @param [String, nil] key path to client private key file
  # @param [String, nil] cert path to client certificate file
  # @param [String, nil] ca path to CA certificate file
  # @param [String, nil] ca_path path to directory with CA certificates
  # @param [String, nil] cipher list of allowed ciphers (not currently used)
  # @return [MysqlPR] self
  def ssl_set(key = nil, cert = nil, ca = nil, ca_path = nil, cipher = nil)
    @ssl_options = {
      key: key,
      cert: cert,
      ca: ca,
      ca_path: ca_path,
      cipher: cipher,
      verify: ca || ca_path ? true : false
    }
    self
  end

  # Configure SSL with additional options.
  # Must be called before connect.
  # @param [Hash] options SSL configuration options
  # @option options [String] :key path to client private key file
  # @option options [String] :cert path to client certificate file
  # @option options [String] :ca path to CA certificate file
  # @option options [String] :ca_path path to directory with CA certificates
  # @option options [Boolean] :verify whether to verify server certificate (default: true if ca provided)
  # @option options [Boolean] :required raise error if server doesn't support SSL
  # @option options [String] :hostname hostname for SNI
  # @option options [Symbol] :min_version minimum TLS version (:TLS1_2, :TLS1_3, etc.)
  # @return [MysqlPR] self
  def ssl_options=(options)
    @ssl_options = options
    self
  end

  # Check if SSL is enabled for the current connection.
  # @return [Boolean] true if SSL is enabled
  def ssl_enabled?
    @protocol&.ssl_enabled? || false
  end

  # Get the SSL cipher being used.
  # @return [Array, nil] cipher info if SSL is enabled, nil otherwise
  def ssl_cipher
    @protocol&.ssl_cipher
  end

  # Escape special character in MySQL.
  # @param [String] str
  # @return [String]
  def escape_string(str)
    self.class.escape_string(str)
  end
  alias quote escape_string

  # @return [String] client version
  def client_info
    self.class.client_info
  end
  alias get_client_info client_info

  # @return [Integer] client version
  def client_version
    self.class.client_version
  end
  alias get_client_version client_version

  # Set charset of MySQL connection.
  # @param [String, MysqlPR::Charset] cs
  def charset=(cs)
    charset = cs.is_a?(Charset) ? cs : Charset.by_name(cs)
    if @protocol
      @protocol.charset = charset
      query("SET NAMES #{charset.name}")
    end
    @charset = charset
    cs
  end

  # @return [String] charset name
  def character_set_name
    @charset.name
  end

  # @return [Integer] last error number
  def errno
    @last_error ? @last_error.errno : 0
  end

  # @return [String] last error message
  def error
    @last_error&.error
  end

  # @return [String] sqlstate for last error
  def sqlstate
    @last_error ? @last_error.sqlstate : "00000"
  end

  # @return [Integer] number of columns for last query
  def field_count
    @fields.size
  end

  # @return [String] connection type
  def host_info
    @host_info
  end
  alias get_host_info host_info

  # @return [Integer] protocol version
  def proto_info
    MysqlPR::Protocol::VERSION
  end
  alias get_proto_info proto_info

  # @return [String] server version
  def server_info
    check_connection
    @protocol.server_info
  end
  alias get_server_info server_info

  # @return [Integer] server version
  def server_version
    check_connection
    @protocol.server_version
  end
  alias get_server_version server_version

  # @return [String] information for last query
  def info
    @protocol&.message
  end

  # @return [Integer] number of affected records by insert/update/delete
  def affected_rows
    @protocol ? @protocol.affected_rows : 0
  end

  # @return [Integer] latest auto_increment value
  def insert_id
    @protocol ? @protocol.insert_id : 0
  end

  # @return [Integer] number of warnings for previous query
  def warning_count
    @protocol ? @protocol.warning_count : 0
  end

  # Kill query.
  # @param [Integer] pid thread id
  # @return [MysqlPR] self
  def kill(pid)
    check_connection
    @protocol.kill_command(pid)
    self
  end

  # Database list.
  # @param [String] db database name that may contain wild card
  # @return [Array<String>] database list
  def list_dbs(db = nil)
    db &&= db.gsub(/[\\\']/) { "\\#{$&}" }
    query(db ? "show databases like '#{db}'" : "show databases").map(&:first)
  end

  # Execute query string.
  # @param [String] str Query
  # @yield [MysqlPR::Result] evaluated per query
  # @return [MysqlPR::Result] If {#query_with_result} is true and result set exist
  # @return [nil] If {#query_with_result} is true and the query does not return result set
  # @return [MysqlPR] If {#query_with_result} is false or block is specified
  # @example
  #  my.query("select 1,NULL,'abc'").fetch  # => [1, nil, "abc"]
  def query(str, &block)
    check_connection
    @fields = nil
    begin
      nfields = @protocol.query_command(str)
      if nfields
        @fields = @protocol.retr_fields(nfields)
        @result_exist = true
      end
      if block
        loop do
          block.call(store_result) if @fields
          break unless next_result
        end
        return self
      end
      if @query_with_result
        return @fields ? store_result : nil
      else
        return self
      end
    rescue ServerError => e
      @last_error = e
      @sqlstate = e.sqlstate
      raise
    end
  end
  alias real_query query

  # Get all data for last query if query_with_result is false.
  # @return [MysqlPR::Result]
  def store_result
    check_connection
    raise ClientError, "invalid usage" unless @result_exist

    res = Result.new(@fields, @protocol)
    @result_exist = false
    res
  end

  # @return [Integer] Thread ID
  def thread_id
    check_connection
    @protocol.thread_id
  end

  # Use result of query. The result data is retrieved when you use MysqlPR::Result#fetch.
  # @return [MysqlPR::Result]
  def use_result
    store_result
  end

  # Set server option.
  # @param [Integer] opt {MysqlPR::OPTION_MULTI_STATEMENTS_ON} or {MysqlPR::OPTION_MULTI_STATEMENTS_OFF}
  # @return [MysqlPR] self
  def set_server_option(opt)
    check_connection
    @protocol.set_option_command(opt)
    self
  end

  # @return [Boolean] true if multiple queries are specified and unexecuted queries exist
  def more_results
    (@protocol.server_status & SERVER_MORE_RESULTS_EXISTS) != 0
  end
  alias more_results? more_results

  # Execute next query if multiple queries are specified.
  # @return [Boolean] true if next query exists
  def next_result
    return false unless more_results

    check_connection
    @fields = nil
    nfields = @protocol.get_result
    if nfields
      @fields = @protocol.retr_fields(nfields)
      @result_exist = true
    end
    true
  end

  # Parse prepared-statement.
  # @param [String] str query string
  # @return [MysqlPR::Stmt] Prepared-statement object
  def prepare(str)
    st = Stmt.new(@protocol, @charset)
    st.prepare(str)
    st
  end

  # Make empty prepared-statement object.
  # @return [MysqlPR::Stmt]
  def stmt_init
    Stmt.new(@protocol, @charset)
  end

  # Returns MysqlPR::Result object that is empty.
  # Use fetch_fields to get list of fields.
  # @param [String] table table name
  # @param [String] field field name that may contain wild card
  # @return [MysqlPR::Result]
  def list_fields(table, field = nil)
    check_connection
    begin
      fields = @protocol.field_list_command(table, field)
      Result.new(fields)
    rescue ServerError => e
      @last_error = e
      @sqlstate = e.sqlstate
      raise
    end
  end

  # @return [MysqlPR::Result] containing process list
  def list_processes
    check_connection
    @fields = @protocol.process_info_command
    @result_exist = true
    store_result
  end

  # @param [String] table database name that may contain wild card
  # @return [Array<String>] list of table name
  def list_tables(table = nil)
    q = table ? "show tables like '#{quote(table)}'" : "show tables"
    query(q).map(&:first)
  end

  # Check whether the connection is available.
  # @return [MysqlPR] self
  def ping
    check_connection
    @protocol.ping_command
    self
  end

  # Flush tables or caches.
  # @param [Integer] op operation. Use MysqlPR::REFRESH_* value
  # @return [MysqlPR] self
  def refresh(op)
    check_connection
    @protocol.refresh_command(op)
    self
  end

  # Reload grant tables.
  # @return [MysqlPR] self
  def reload
    refresh(MysqlPR::REFRESH_GRANT)
  end

  # Select default database
  # @return [MysqlPR] self
  def select_db(db)
    query("use #{db}")
    self
  end

  # Shutdown server.
  # @return [MysqlPR] self
  def shutdown(level = 0)
    check_connection
    @protocol.shutdown_command(level)
    self
  end

  # @return [String] statistics message
  def stat
    @protocol ? @protocol.statistics_command : "MySQL server has gone away"
  end

  # Commit transaction
  # @return [MysqlPR] self
  def commit
    query("commit")
    self
  end

  # Rollback transaction
  # @return [MysqlPR] self
  def rollback
    query("rollback")
    self
  end

  # Set autocommit mode
  # @param [Boolean] flag
  # @return [MysqlPR] self
  def autocommit(flag)
    query("set autocommit=#{flag ? 1 : 0}")
    self
  end

  private

  def check_connection
    raise ClientError::ServerGoneError, "The MySQL server has gone away" unless @protocol
  end

  # Field class
  class Field
    # @return [String] database name
    attr_reader :db
    # @return [String] table name
    attr_reader :table
    # @return [String] original table name
    attr_reader :org_table
    # @return [String] field name
    attr_reader :name
    # @return [String] original field name
    attr_reader :org_name
    # @return [Integer] charset id number
    attr_reader :charsetnr
    # @return [Integer] field length
    attr_reader :length
    # @return [Integer] field type
    attr_reader :type
    # @return [Integer] flag
    attr_reader :flags
    # @return [Integer] number of decimals
    attr_reader :decimals
    # @return [String] default value
    attr_reader :default

    alias def default

    attr_accessor :result
    attr_writer :max_length

    # @param [Protocol::FieldPacket] packet
    def initialize(packet)
      @db = packet.db
      @table = packet.table
      @org_table = packet.org_table
      @name = packet.name
      @org_name = packet.org_name
      @charsetnr = packet.charsetnr
      @length = packet.length
      @type = packet.type
      @flags = packet.flags
      @decimals = packet.decimals
      @default = packet.default
      @flags |= NUM_FLAG if num_type?
      @max_length = nil
      @result = nil
    end

    # @return [Hash] field information
    def to_hash
      {
        "name"       => @name,
        "table"      => @table,
        "def"        => @default,
        "type"       => @type,
        "length"     => @length,
        "max_length" => max_length,
        "flags"      => @flags,
        "decimals"   => @decimals
      }
    end
    alias hash to_hash

    def inspect
      "#<MysqlPR::Field:#{@name}>"
    end

    # @return [Boolean] true if numeric field
    def is_num?
      (@flags & NUM_FLAG) != 0
    end

    # @return [Boolean] true if not null field
    def is_not_null?
      (@flags & NOT_NULL_FLAG) != 0
    end

    # @return [Boolean] true if primary key field
    def is_pri_key?
      (@flags & PRI_KEY_FLAG) != 0
    end

    # @return [Integer] maximum width of the field for the result set
    def max_length
      return @max_length if @max_length

      @max_length = 0
      @result&.calculate_field_max_length
      @max_length
    end

    private

    def num_type?
      [TYPE_DECIMAL, TYPE_TINY, TYPE_SHORT, TYPE_LONG, TYPE_FLOAT,
       TYPE_DOUBLE, TYPE_LONGLONG, TYPE_INT24].include?(@type) ||
        (@type == TYPE_TIMESTAMP && (@length == 14 || @length == 8))
    end
  end

  # Result set base class
  class ResultBase
    include Enumerable

    # @return [Array<MysqlPR::Field>] field list
    attr_reader :fields

    # @param [Array<MysqlPR::Field>] fields
    def initialize(fields)
      @fields = fields
      @field_index = 0
      @records = []
      @index = 0
      @fieldname_with_table = nil
      @fetched_record = nil
    end

    # @return [void]
    def free; end

    # @return [Integer] number of records
    def size
      @records.size
    end
    alias num_rows size

    # @return [Array, nil] current record data
    def fetch
      @fetched_record = nil
      return nil if @index >= @records.size

      @records[@index] = @records[@index].to_a unless @records[@index].is_a?(Array)
      @fetched_record = @records[@index]
      @index += 1
      @fetched_record
    end
    alias fetch_row fetch

    # Return data of current record as Hash.
    # @param [Boolean] with_table if true, hash key is "table_name.field_name"
    # @return [Hash, nil] current record data
    def fetch_hash(with_table = nil)
      row = fetch
      return nil unless row

      if with_table && @fieldname_with_table.nil?
        @fieldname_with_table = @fields.map { |f| "#{f.table}.#{f.name}" }
      end
      ret = {}
      @fields.each_index do |i|
        fname = with_table ? @fieldname_with_table[i] : @fields[i].name
        ret[fname] = row[i]
      end
      ret
    end

    # Iterate block with record.
    # @yield [Array] record data
    # @return [self, Enumerator]
    def each(&block)
      return enum_for(:each) unless block

      while (rec = fetch)
        block.call(rec)
      end
      self
    end

    # Iterate block with record as Hash.
    # @param [Boolean] with_table if true, hash key is "table_name.field_name"
    # @yield [Hash] record data
    # @return [self, Enumerator]
    def each_hash(with_table = nil, &block)
      return enum_for(:each_hash, with_table) unless block

      while (rec = fetch_hash(with_table))
        block.call(rec)
      end
      self
    end

    # Set record position
    # @param [Integer] n record index
    # @return [self]
    def data_seek(n)
      @index = n
      self
    end

    # @return [Integer] current record position
    def row_tell
      @index
    end

    # Set current position of record
    # @param [Integer] n record index
    # @return [Integer] previous position
    def row_seek(n)
      ret = @index
      @index = n
      ret
    end
  end

  # Result set for simple query
  class Result < ResultBase
    # @param [Array<MysqlPR::Field>] fields
    # @param [MysqlPR::Protocol, nil] protocol
    def initialize(fields, protocol = nil)
      super(fields)
      return unless protocol

      @records = protocol.retr_all_records(fields.size)
      fields.each { |f| f.result = self }
    end

    # Calculate max_length of all fields
    def calculate_field_max_length
      max_length = Array.new(@fields.size, 0)
      @records.each_with_index do |rec, i|
        rec = @records[i] = rec.to_a if rec.is_a?(RawRecord)
        max_length.each_index do |j|
          max_length[j] = rec[j].length if rec[j] && rec[j].length > max_length[j]
        end
      end
      max_length.each_with_index do |len, i|
        @fields[i].max_length = len
      end
    end

    # @return [MysqlPR::Field, nil] current field
    def fetch_field
      return nil if @field_index >= @fields.length

      ret = @fields[@field_index]
      @field_index += 1
      ret
    end

    # @return [Integer] current field position
    def field_tell
      @field_index
    end

    # Set field position
    # @param [Integer] n field index
    # @return [Integer] previous position
    def field_seek(n)
      ret = @field_index
      @field_index = n
      ret
    end

    # Return specified field
    # @param [Integer] n field index
    # @return [MysqlPR::Field] field
    def fetch_field_direct(n)
      raise ClientError, "invalid argument: #{n}" if n.negative? || n >= @fields.length

      @fields[n]
    end

    # @return [Array<MysqlPR::Field>] all fields
    def fetch_fields
      @fields
    end

    # @return [Array<Integer>, nil] length of each field
    def fetch_lengths
      return nil unless @fetched_record

      @fetched_record.map { |c| c.nil? ? 0 : c.length }
    end

    # @return [Integer] number of fields
    def num_fields
      @fields.size
    end
  end

  # Result set for prepared statement
  class StatementResult < ResultBase
    # @param [Array<MysqlPR::Field>] fields
    # @param [MysqlPR::Protocol] protocol
    # @param [MysqlPR::Charset] charset
    def initialize(fields, protocol, charset)
      super(fields)
      @records = protocol.stmt_retr_all_records(@fields, charset)
    end
  end

  # Prepared statement
  # @!attribute [r] affected_rows
  #   @return [Integer]
  # @!attribute [r] insert_id
  #   @return [Integer]
  # @!attribute [r] server_status
  #   @return [Integer]
  # @!attribute [r] warning_count
  #   @return [Integer]
  # @!attribute [r] param_count
  #   @return [Integer]
  # @!attribute [r] fields
  #   @return [Array<MysqlPR::Field>]
  # @!attribute [r] sqlstate
  #   @return [String]
  class Stmt
    include Enumerable

    attr_reader :affected_rows, :insert_id, :server_status, :warning_count
    attr_reader :param_count, :fields, :sqlstate

    def self.finalizer(protocol, statement_id)
      proc do
        protocol.gc_stmt(statement_id)
      end
    end

    # @param [MysqlPR::Protocol] protocol
    # @param [MysqlPR::Charset] charset
    def initialize(protocol, charset)
      @protocol = protocol
      @charset = charset
      @statement_id = nil
      @affected_rows = 0
      @insert_id = 0
      @server_status = 0
      @warning_count = 0
      @sqlstate = "00000"
      @param_count = nil
      @bind_result = nil
      @result = nil
      @fields = nil
      @last_error = nil
    end

    # Parse prepared-statement and return {MysqlPR::Stmt} object
    # @param [String] str query string
    # @return [MysqlPR::Stmt] self
    def prepare(str)
      close
      begin
        @sqlstate = "00000"
        @statement_id, @param_count, @fields = @protocol.stmt_prepare_command(str)
      rescue ServerError => e
        @last_error = e
        @sqlstate = e.sqlstate
        raise
      end
      ObjectSpace.define_finalizer(self, self.class.finalizer(@protocol, @statement_id))
      self
    end

    # Execute prepared statement.
    # @param [Object] values values passed to query
    # @return [MysqlPR::Stmt] self
    def execute(*values)
      raise ClientError, "not prepared" unless @param_count
      raise ClientError, "parameter count mismatch" if values.length != @param_count

      values = values.map { |v| @charset.convert(v) }
      begin
        @sqlstate = "00000"
        nfields = @protocol.stmt_execute_command(@statement_id, values)
        if nfields
          @fields = @protocol.retr_fields(nfields)
          @result = StatementResult.new(@fields, @protocol, @charset)
        else
          @affected_rows = @protocol.affected_rows
          @insert_id = @protocol.insert_id
          @server_status = @protocol.server_status
          @warning_count = @protocol.warning_count
          @info = @protocol.message
        end
        self
      rescue ServerError => e
        @last_error = e
        @sqlstate = e.sqlstate
        raise
      end
    end

    # Close prepared statement
    # @return [void]
    def close
      ObjectSpace.undefine_finalizer(self)
      @protocol.stmt_close_command(@statement_id) if @statement_id
      @statement_id = nil
    end

    # @return [Array, nil] current record data
    def fetch
      row = @result.fetch
      return row unless @bind_result

      row.zip(@bind_result).map do |col, type|
        if col.nil?
          nil
        elsif [Numeric, Integer].include?(type)
          col.to_i
        elsif type == String
          col.to_s
        elsif type == Float && !col.is_a?(Float)
          col.to_i.to_f
        elsif type == MysqlPR::Time && !col.is_a?(MysqlPR::Time)
          parse_time_value(col)
        else
          col
        end
      end
    end

    # Return data of current record as Hash.
    # @param [Boolean] with_table if true, hash key is "table_name.field_name"
    # @return [Hash, nil] record data
    def fetch_hash(with_table = nil)
      @result.fetch_hash(with_table)
    end

    # Set retrieve type of value
    # @param [Class] args value type (Numeric, Integer, Float, String, MysqlPR::Time, or nil)
    # @return [MysqlPR::Stmt] self
    def bind_result(*args)
      if @fields.length != args.length
        raise ClientError, "bind_result: result value count(#{@fields.length}) != number of argument(#{args.length})"
      end

      args.each do |a|
        unless [Numeric, Integer, Float, String, MysqlPR::Time, nil].include?(a)
          raise TypeError, "unsupported type: #{a}"
        end
      end
      @bind_result = args
      self
    end

    # Iterate block with record.
    # @yield [Array] record data
    # @return [MysqlPR::Stmt, Enumerator] self or Enumerator if block not specified
    def each(&block)
      return enum_for(:each) unless block

      while (rec = fetch)
        block.call(rec)
      end
      self
    end

    # Iterate block with record as Hash.
    # @param [Boolean] with_table if true, hash key is "table_name.field_name"
    # @yield [Hash] record data
    # @return [MysqlPR::Stmt, Enumerator] self or Enumerator if block not specified
    def each_hash(with_table = nil, &block)
      return enum_for(:each_hash, with_table) unless block

      while (rec = fetch_hash(with_table))
        block.call(rec)
      end
      self
    end

    # @return [Integer] number of records
    def size
      @result.size
    end
    alias num_rows size

    # Set record position
    # @param [Integer] n record index
    # @return [void]
    def data_seek(n)
      @result.data_seek(n)
    end

    # @return [Integer] current record position
    def row_tell
      @result.row_tell
    end

    # Set current position of record
    # @param [Integer] n record index
    # @return [Integer] previous position
    def row_seek(n)
      @result.row_seek(n)
    end

    # @return [Integer] number of columns for last query
    def field_count
      @fields.length
    end

    # @return [void]
    def free_result; end

    # Returns MysqlPR::Result object that is empty.
    # Use fetch_fields to get list of fields.
    # @return [MysqlPR::Result, nil]
    def result_metadata
      return nil if @fields.empty?

      Result.new(@fields)
    end

    private

    def parse_time_value(col)
      return MysqlPR::Time.new unless col.to_s =~ /\A\d+\z/

      i = col.to_s.to_i
      if i < 100_000_000
        y = i / 10_000
        m = (i / 100) % 100
        d = i % 100
        h = mm = s = 0
      else
        y = i / 10_000_000_000
        m = (i / 100_000_000) % 100
        d = (i / 1_000_000) % 100
        h = (i / 10_000) % 100
        mm = (i / 100) % 100
        s = i % 100
      end
      y += 2000 if y < 70
      y += 1900 if y >= 70 && y < 100
      MysqlPR::Time.new(y, m, d, h, mm, s)
    end
  end

  # MySQL Time class
  # @!attribute [rw] year
  #   @return [Integer]
  # @!attribute [rw] month
  #   @return [Integer]
  # @!attribute [rw] day
  #   @return [Integer]
  # @!attribute [rw] hour
  #   @return [Integer]
  # @!attribute [rw] minute
  #   @return [Integer]
  # @!attribute [rw] second
  #   @return [Integer]
  # @!attribute [rw] neg
  #   @return [Boolean] negative flag
  # @!attribute [rw] second_part
  #   @return [Integer]
  class Time
    attr_accessor :year, :month, :day, :hour, :minute, :second, :neg, :second_part

    alias mon month
    alias min minute
    alias sec second

    # @param [Integer] year
    # @param [Integer] month
    # @param [Integer] day
    # @param [Integer] hour
    # @param [Integer] minute
    # @param [Integer] second
    # @param [Boolean] neg negative flag
    # @param [Integer] second_part
    def initialize(year = 0, month = 0, day = 0, hour = 0, minute = 0, second = 0, neg = false, second_part = 0)
      @date_flag = !(hour && minute && second)
      @year = year.to_i
      @month = month.to_i
      @day = day.to_i
      @hour = hour.to_i
      @minute = minute.to_i
      @second = second.to_i
      @neg = neg
      @second_part = second_part.to_i
    end

    def ==(other)
      other.is_a?(MysqlPR::Time) &&
        @year == other.year && @month == other.month && @day == other.day &&
        @hour == other.hour && @minute == other.minute && @second == other.second &&
        @neg == other.neg && @second_part == other.second_part
    end

    def eql?(other)
      self == other
    end

    # @return [String] "yyyy-mm-dd HH:MM:SS"
    def to_s
      if @date_flag
        format("%04d-%02d-%02d", year, mon, day)
      elsif year.zero? && mon.zero? && day.zero?
        h = neg ? hour * -1 : hour
        format("%02d:%02d:%02d", h, min, sec)
      else
        format("%04d-%02d-%02d %02d:%02d:%02d", year, mon, day, hour, min, sec)
      end
    end

    # @return [Integer] yyyymmddHHMMSS
    def to_i
      format("%04d%02d%02d%02d%02d%02d", year, mon, day, hour, min, sec).to_i
    end

    def inspect
      format("#<#{self.class.name}:%04d-%02d-%02d %02d:%02d:%02d>", year, mon, day, hour, min, sec)
    end
  end
end
