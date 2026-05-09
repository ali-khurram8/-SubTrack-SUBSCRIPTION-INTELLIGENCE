-- Fix password hashes for all sample users (password: Password123!)
UPDATE users SET password_hash = '$2a$10$RtV66nKVksWY5BPoIP8YtOCsTZlLxiZNz6M8toEMdVtkWwx.covCC';
