-- PowerDNS PostgreSQL schema (4.9.x compatible)
-- Source: https://doc.powerdns.com/authoritative/backends/generic-postgresql.html

CREATE TABLE domains (
  id                    SERIAL PRIMARY KEY,
  name                  VARCHAR(255) NOT NULL,
  master                VARCHAR(128) DEFAULT NULL,
  last_check            INT DEFAULT NULL,
  type                  VARCHAR(6) NOT NULL,
  notified_serial       INT DEFAULT NULL,
  account               VARCHAR(40) DEFAULT NULL,
  options               TEXT DEFAULT NULL,
  catalog               VARCHAR(255) DEFAULT NULL
);

CREATE UNIQUE INDEX name_index ON domains(name);

CREATE TABLE records (
  id                    BIGSERIAL PRIMARY KEY,
  domain_id             INT DEFAULT NULL,
  name                  VARCHAR(255) DEFAULT NULL,
  type                  VARCHAR(10) DEFAULT NULL,
  content               VARCHAR(65535) DEFAULT NULL,
  ttl                   INT DEFAULT NULL,
  prio                  INT DEFAULT NULL,
  disabled              BOOL DEFAULT 'f',
  ordername             VARCHAR(255),
  auth                  BOOL DEFAULT 't',
  CONSTRAINT domain_id
    FOREIGN KEY(domain_id) REFERENCES domains(id)
    ON DELETE CASCADE
);

CREATE INDEX records_domain_id ON records(domain_id);
CREATE INDEX records_name ON records(name);
CREATE INDEX records_type ON records(type);

CREATE TABLE supermasters (
  ip                    INET NOT NULL,
  nameserver            VARCHAR(255) NOT NULL,
  account               VARCHAR(40) NOT NULL,
  PRIMARY KEY(ip, nameserver)
);

CREATE TABLE comments (
  id                    SERIAL PRIMARY KEY,
  domain_id             INT NOT NULL,
  name                  VARCHAR(255) NOT NULL,
  type                  VARCHAR(10) NOT NULL,
  modified_at           INT NOT NULL,
  account               VARCHAR(40) DEFAULT NULL,
  comment               VARCHAR(65535) NOT NULL,
  CONSTRAINT domain_id
    FOREIGN KEY(domain_id) REFERENCES domains(id)
    ON DELETE CASCADE
);

CREATE INDEX comments_domain_id ON comments(domain_id);
CREATE INDEX comments_name ON comments(name);
CREATE INDEX comments_type ON comments(type);

CREATE TABLE domainmetadata (
  id                    SERIAL PRIMARY KEY,
  domain_id             INT NOT NULL,
  kind                  VARCHAR(32),
  content               TEXT,
  CONSTRAINT domain_id
    FOREIGN KEY(domain_id) REFERENCES domains(id)
    ON DELETE CASCADE
);

CREATE INDEX domainmetadata_domain_id ON domainmetadata(domain_id);

CREATE TABLE cryptokeys (
  id                    SERIAL PRIMARY KEY,
  domain_id             INT NOT NULL,
  flags                 INT NOT NULL,
  active                BOOL,
  published             BOOL DEFAULT TRUE,
  content               TEXT,
  CONSTRAINT domain_id
    FOREIGN KEY(domain_id) REFERENCES domains(id)
    ON DELETE CASCADE
);

CREATE INDEX cryptokeys_domain_id ON cryptokeys(domain_id);

CREATE TABLE tsigkeys (
  id                    SERIAL PRIMARY KEY,
  name                  VARCHAR(255) DEFAULT NULL,
  algorithm             VARCHAR(50) DEFAULT NULL,
  secret                VARCHAR(255) DEFAULT NULL,
  CONSTRAINT c_lowercase_name CHECK (((name)::text = lower((name)::text)))
);

CREATE UNIQUE INDEX namealgoindex ON tsigkeys(name, algorithm);

CREATE TABLE recordcomments (
  id                    SERIAL PRIMARY KEY,
  domain_id             INT NOT NULL,
  name                  VARCHAR(255) NOT NULL,
  type                  VARCHAR(10) NOT NULL,
  modified_at           INT NOT NULL,
  account               VARCHAR(40) DEFAULT NULL,
  comment               VARCHAR(65535) NOT NULL,
  CONSTRAINT domain_id
    FOREIGN KEY(domain_id) REFERENCES domains(id)
    ON DELETE CASCADE
);

CREATE INDEX recordcomments_domain_id ON recordcomments(domain_id);
CREATE INDEX recordcomments_name ON recordcomments(name);
CREATE INDEX recordcomments_type ON recordcomments(type);

CREATE TABLE tlsoptions (
  id                    SERIAL PRIMARY KEY,
  domain_id             INT NOT NULL,
  kind                  VARCHAR(32),
  content               TEXT,
  CONSTRAINT domain_id
    FOREIGN KEY(domain_id) REFERENCES domains(id)
    ON DELETE CASCADE
);

CREATE INDEX tlsoptions_domain_id ON tlsoptions(domain_id);
