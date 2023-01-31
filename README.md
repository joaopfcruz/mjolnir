# mjolnir

Init VM: (1) bash -c "$(curl -fsSL https://raw.githubusercontent.com/joaopfcruz/mjolnir/main/init/mgmt_vm_init.sh)"

Init mjonir (w/ non-root user): (2) bash -c "$(curl -fsSL https://raw.githubusercontent.com/joaopfcruz/mjolnir/main/init/mjolnir_setup.sh)" && source $HOME/.bashrc

Init axiom (w/ non-root user): (3) curl -fsSL https://raw.githubusercontent.com/joaopfcruz/mjolnir/main/init/axiom-init-first-run.sh | bash -s -- -e dev/prod -t digital_ocean_token 
