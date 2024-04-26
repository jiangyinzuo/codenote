same between v0.10.1 and v0.10.2

src/include/duckdb/common/types.hpp:184-233 version=v0.10.2 snippet_id=1
```cpp
enum class LogicalTypeId : uint8_t {
	INVALID = 0,
	SQLNULL = 1, /* NULL type, used for constant NULL */
	UNKNOWN = 2, /* unknown type, used for parameter expressions */
	ANY = 3,     /* ANY type, used for functions that accept any type as parameter */
	USER = 4,    /* A User Defined Type (e.g., ENUMs before the binder) */
	BOOLEAN = 10,
	TINYINT = 11,
	SMALLINT = 12,
	INTEGER = 13,
	BIGINT = 14,
	DATE = 15,
	TIME = 16,
	TIMESTAMP_SEC = 17,
	TIMESTAMP_MS = 18,
	TIMESTAMP = 19, //! us
	TIMESTAMP_NS = 20,
	DECIMAL = 21,
	FLOAT = 22,
	DOUBLE = 23,
	CHAR = 24,
	VARCHAR = 25,
	BLOB = 26,
	INTERVAL = 27,
	UTINYINT = 28,
	USMALLINT = 29,
	UINTEGER = 30,
	UBIGINT = 31,
	TIMESTAMP_TZ = 32,
	TIME_TZ = 34,
	BIT = 36,
	STRING_LITERAL = 37, /* string literals, used for constant strings - only exists while binding */
	INTEGER_LITERAL = 38,/* integer literals, used for constant integers - only exists while binding */

	UHUGEINT = 49,
	HUGEINT = 50,
	POINTER = 51,
	VALIDITY = 53,
	UUID = 54,

	STRUCT = 100,
	LIST = 101,
	MAP = 102,
	TABLE = 103,
	ENUM = 104,
	AGGREGATE_STATE = 105,
	LAMBDA = 106,
	UNION = 107,
	ARRAY = 108
};
```

