---
title:      "Kjell-Magne Øierud :: IPv6 addresses and MySQL"
date:       2009-02-19 11:49:50.00000 +01:00
layout:     bliki
---

I usually prefer storing IP addresses as integers (unless the DBMS
have a special data type for it). Using integers gives compact storage
and makes it easy to answer questions like what is the next IP
address? In which subnets does it belong? Etc. IPv6 addresses is 128
bits long, so to store that as an integer in MySQL you need to use
the `DECIMAL` data type.


In MySQL there is two functions that help you translate between the
familiar canonical version and the numeric version of IP addresses:
`INET_ATON()` and `INET_NTOA()`. However these functions do not work
with IPv6 addresses.

One possible solution to this is to implement `INET_ATON6()` and
`INET_NTOA6()` yourself as stored functions:

### INET_ATON6

``` sql
DELIMITER //
CREATE FUNCTION INET_ATON6(n CHAR(39))
RETURNS DECIMAL(39) UNSIGNED
DETERMINISTIC
BEGIN
    RETURN CAST(CONV(SUBSTRING(n FROM  1 FOR 4), 16, 10) AS DECIMAL(39))
                       * 5192296858534827628530496329220096 -- 65536 ^ 7
         + CAST(CONV(SUBSTRING(n FROM  6 FOR 4), 16, 10) AS DECIMAL(39))
                       *      79228162514264337593543950336 -- 65536 ^ 6
         + CAST(CONV(SUBSTRING(n FROM 11 FOR 4), 16, 10) AS DECIMAL(39))
                       *          1208925819614629174706176 -- 65536 ^ 5
         + CAST(CONV(SUBSTRING(n FROM 16 FOR 4), 16, 10) AS DECIMAL(39))
                       *               18446744073709551616 -- 65536 ^ 4
         + CAST(CONV(SUBSTRING(n FROM 21 FOR 4), 16, 10) AS DECIMAL(39))
                       *                    281474976710656 -- 65536 ^ 3
         + CAST(CONV(SUBSTRING(n FROM 26 FOR 4), 16, 10) AS DECIMAL(39))
                       *                         4294967296 -- 65536 ^ 2
         + CAST(CONV(SUBSTRING(n FROM 31 FOR 4), 16, 10) AS DECIMAL(39))
                       *                              65536 -- 65536 ^ 1
         + CAST(CONV(SUBSTRING(n FROM 36 FOR 4), 16, 10) AS DECIMAL(39))
         ;
END;
//
DELIMITER ;
```

<h3>INET_NTOA6</h3>

``` sql
DELIMITER //
CREATE FUNCTION INET_NTOA6(n DECIMAL(39) UNSIGNED)
RETURNS CHAR(39)
DETERMINISTIC
BEGIN
  DECLARE a CHAR(39)             DEFAULT '';
  DECLARE i INT                  DEFAULT 7;
  DECLARE q DECIMAL(39) UNSIGNED DEFAULT 0;
  DECLARE r INT                  DEFAULT 0;
  WHILE i DO
    -- DIV doesn't work with nubers > bigint
    SET q := FLOOR(n / 65536);
    SET r := n MOD 65536;
    SET n := q;
    SET a := CONCAT_WS(':', LPAD(CONV(r, 10, 16), 4, '0'), a);

    SET i := i - 1;
  END WHILE;

  SET a := TRIM(TRAILING ':' FROM CONCAT_WS(':',
                                            LPAD(CONV(n, 10, 16), 4, '0'),
                                            a));

  RETURN a;

END;
//
DELIMITER ;
```

<p>The code is to be regarded as a proof of concept as it needs sanity
checks and handling of simplified address notations before production
use. However the following small test verifies that it is not
completely broken:</p>

<div class="highlight">
<pre>
mysql> <strong>SELECT INET_NTOA6(INET_ATON6(</strong>
    ->   <strong>'2001:0db8:85a3:0000:0000:8a2e:0370:7334'));</strong>
+-------------------------------------------------------------------+
| INET_NTOA6(INET_ATON6('2001:0db8:85a3:0000:0000:8a2e:0370:7334')) |
+-------------------------------------------------------------------+
| 2001:0DB8:85A3:0000:0000:8A2E:0370:7334                           |
+-------------------------------------------------------------------+
1 row in set (0.00 sec)

mysql> <strong>SELECT INET_NTOA6(INET_ATON6(</strong>
    ->   <strong>'ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff'));</strong>
+-------------------------------------------------------------------+
| INET_NTOA6(INET_ATON6('ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff')) |
+-------------------------------------------------------------------+
| FFFF:FFFF:FFFF:FFFF:FFFF:FFFF:FFFF:FFFF                           |
+-------------------------------------------------------------------+
1 row in set (0.00 sec)

mysql> <strong>select INET_NTOA6(INET_ATON6(</strong>
    ->   <strong>'0000:0000:0000:0000:0000:0000:0000:0000'));</strong>
+-------------------------------------------------------------------+
| INET_NTOA6(INET_ATON6('0000:0000:0000:0000:0000:0000:0000:0000')) |
+-------------------------------------------------------------------+
| 0000:0000:0000:0000:0000:0000:0000:0000                           |
+-------------------------------------------------------------------+
1 row in set (0.01 sec)
</pre>
</div>
