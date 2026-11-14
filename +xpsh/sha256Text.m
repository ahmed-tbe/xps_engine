function digest = sha256Text(value)
%SHA256TEXT Lower-case SHA-256 digest of UTF-8 text.

value = join(string(value),newline);
engine = java.security.MessageDigest.getInstance("SHA-256");
engine.update(unicode2native(char(value),"UTF-8"));
digest = lower(string(reshape(dec2hex(typecast(engine.digest(),"uint8"),2).',1,[])));
end
