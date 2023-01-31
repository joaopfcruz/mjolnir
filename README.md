# mjolnir

Init VM: (1) bash -c "$(curl -fsSL https://raw.githubusercontent.com/joaopfcruz/mjolnir/main/init/mgmt_vm_init.sh)"


Init axiom (w/ non-root user): (2) curl -fsSL https://raw.githubusercontent.com/joaopfcruz/mjolnir/main/init/axiom-init-first-run.sh | bash -s -- -e dev/prod -t digital_ocean_token 

Init mjonir: (3) bash -c "$(curl -fsSL https://raw.githubusercontent.com/joaopfcruz/mjolnir/main/init/mjolnir_setup.sh)" && source $HOME/.bashrc
