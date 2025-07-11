Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  
  ["db", "backend", "frontend"].each_with_index do |name, i|
    config.vm.define name do |node|
      node.vm.hostname = name
      node.vm.network "private_network", ip: "192.168.56.#{10 + i}"
      node.vm.provision "ansible", run: "once" do |ansible|
        ansible.playbook = "playbooks/site.yml"
        ansible.groups = {
          "db" => ["db"],
          "backend" => ["backend"],
          "frontend" => ["frontend"]
        }
      end
    end
  end
end