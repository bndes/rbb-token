import { Component, OnInit } from '@angular/core';
import { Web3Service } from './../Web3Service';

@Component({
  selector: 'app-home',
  templateUrl: './home.component.html',
  styleUrls: ['./home.component.css']
})
export class HomeComponent implements OnInit {

  nomeRedeBlockchain: string;
  addrContratoRBBToken: string;
  addrContratoESGBndesToken: string;
  numeroBlockchainNetwork: string;
  URLBlockchainProvider: string;
  netVersion: string;
  selectedAccount: any; 

  constructor(private web3Service: Web3Service) {

      let self = this;
      setInterval(function () {
        self.recuperaContaSelecionada(), 
        1000});
    }

  ngOnInit() {
    let infoBlockchainNetwork = this.web3Service.getInfoBlockchain();
    this.nomeRedeBlockchain = infoBlockchainNetwork.nomeRedeBlockchain;
    this.addrContratoRBBToken = infoBlockchainNetwork.addrContratoRBBToken;
    this.addrContratoESGBndesToken = infoBlockchainNetwork.addrContratoESGBndesToken;
    this.URLBlockchainProvider = infoBlockchainNetwork.URLBlockchainProvider;
    this.numeroBlockchainNetwork = infoBlockchainNetwork.numeroBlockchainNetwork;
    this.netVersion = infoBlockchainNetwork.netVersion;
  }

  conectar () {
    this.web3Service.conectar();
  }


  async recuperaContaSelecionada() {

    let self = this;
    
    let newSelectedAccount = await this.web3Service.getCurrentAccountSync();

    if ( !self.selectedAccount || (newSelectedAccount !== self.selectedAccount && newSelectedAccount)) {

      this.selectedAccount = newSelectedAccount;
      console.log("selectedAccount=" + this.selectedAccount);
    }

  }

}
