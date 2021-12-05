module LoadConfig
  def load_config
    YAML.load_file "#{PATH}/config/config.yml"
  end

  def load_secrets
    YAML.load_file "#{PATH}/config/secrets.yml"
  end
end
