defmodule Fact.Types do
  @moduledoc """
  Defines the types which are used to within the package.
    

    
  """

  @typedoc """
  The date and time when an `t:Fact.event_record/0` was written to disk.
  """
  @type event_timestamp :: unix_microseconds()

  @typedoc """
  A UNIX timestamp with microsecond precision.
    
  The number of microseconds since January 1st, 1970 at 00:00 (UTC).
  """
  @type unix_microseconds() :: integer()

  @typedoc """
  A UUID v4 base32 encoded, uppercase, without padding characters.
  """
  @type uppercase_base32_uuid_v4_sans_padding :: String.t()

  @typedoc """
  A string that is not empty or solely consists of whitespace characters.
  """
  @type non_whitespace_string :: String.t()
end
