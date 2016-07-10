require 'registry_client'

class EventService
  def self.registry_add(event_id)
    e = Events::RegistryAdd.where(id: event_id).first
    cl = RegistryClient.new(e.url)
    cl.register(e.our_url) do |id|
      e.registry = Registry.create(
        url: e.url,
        our_url: e.our_url,
        public_id: UUID.generate,
        registered_public_id: id,
      )
      e.save
    end
  end

  def self.registry_destroy(event_id)
    e = Events::RegistryDestroy.where(id: event_id).first
    registry = Registry.where(public_id: e.registry_id).first
    cl = RegistryClient.new(registry.url)
    cl.deregister(registry.registered_public_id)
    registry.destroy
  end

  def self.rule_add(event_id)
    e = Events::RuleAdd.where(id: event_id).first
    ns = Namespace.where(public_id: e.namespace_id).first
    rule = Rule.create(name: e.name, namespace: ns, public_id: UUID.generate)
    Version.create(src: e.src, rule: rule)
    ParseService.parse_versions(rule._id.to_s)

    ver = rule.versions.first.code
    Registry.all.each do |registry|
      cl = RegistryClient.new(registry.url)      
      cl.create_rule(rule.namespace.name, rule.name, ver, registry.registered_public_id) do |public_id|
        Registration.create(registry_public_id: registry.public_id, rule_public_id: public_id, version: ver, rule: rule)
      end
    end
    
    e.rule = rule
    e.save
  end

  def self.rule_destroy(event_id)
    e = Events::RuleDestroy.where(id: event_id).first
    rule = Rule.where(public_id: e.rule_id).first
    rule.registrations.each do |r|
      p [:r, r]
      registry = Registry.where(public_id: r.registry_public_id).first
      cl = RegistryClient.new(registry.url)
      cl.delete_rule(r.registry_public_id, r.rule_public_id) do
        Rails.logger.info("! deleted rule #{r.rule_public_id} on #{r.registry_public_id}")
      end
    end
    rule.destroy
  end

  def self.namespace_add(event_id)
    e = Events::NamespaceAdd.where(id: event_id).first
    ns = Namespace.create(name: e.name, public_id: UUID.generate)
    e.namespace = ns
    e.save
  end

  def self.namespace_destroy(event_id)
    e = Events::NamespaceDestroy.where(id: event_id).first
    Namespace.where(public_id: e.namespace_id).first.destroy
  end
end
  
