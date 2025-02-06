CREATE TABLE users
(
    userid       int not null AUTO_INCREMENT,
    username     varchar(64) not null,
    pwdhash      varchar(256) not null,
    PRIMARY KEY  (userid),
    UNIQUE       (username)
);


ALTER TABLE users AUTO_INCREMENT = 80001;
CREATE USER 'organa-read-only' IDENTIFIED BY 'abc123!!';
CREATE USER 'organa-read-write' IDENTIFIED BY 'def456!!';


