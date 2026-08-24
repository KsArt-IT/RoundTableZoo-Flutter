-- data-model.md §1.1-1.2

CREATE TABLE rate_limits (
  day        TEXT    NOT NULL,   -- 'yyyy-mm-dd', UTC (research.md R9)
  install_id TEXT    NOT NULL,   -- как пришёл от клиента, после проверки подлинности
  count      INTEGER NOT NULL,
  PRIMARY KEY (day, install_id)
);

CREATE TABLE global_limits (
  day   TEXT    NOT NULL,   -- 'yyyy-mm-dd', UTC
  model TEXT    NOT NULL,   -- квоты провайдера считаются по моделям отдельно
  count INTEGER NOT NULL,
  PRIMARY KEY (day, model)
);
