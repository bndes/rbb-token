import { Component, OnInit, NgZone } from '@angular/core';
import { ChangeDetectorRef } from '@angular/core';
import {DashboardPapeis} from './DashboardPapeis';
import { Web3Service } from './../Web3Service';
import { BnAlertsService } from 'bndes-ux4';

@Component({
  selector: 'app-dashboard-papeis',
  templateUrl: './dashboard-papeis.component.html',
  styleUrls: ['./dashboard-papeis.component.css']
})
export class DashboardPapeisComponent implements OnInit {

  listaTransacoes: DashboardPapeis[] = undefined;

  blockchainNetworkPrefix: string;

  estadoLista: string = "undefined";

  p: number = 1;
  order: string = 'dataHora';
  reverse: boolean = false;

  selectedAccount: any;

  constructor(protected bnAlertsService: BnAlertsService, private web3Service: Web3Service,
    private ref: ChangeDetectorRef, private zone: NgZone) { 

      let self = this;
      self.recuperaContaSelecionada();
                  
      setInterval(function () {
        self.recuperaContaSelecionada(), 
        1000}); 


    }

    ngOnInit() {
  
      //TODO: ajustar esse codigo em todos os dashboards. Precisa do primeiro timeout? Não eh perigoso usar uma dependencia fixa de tempo? 
      setTimeout(() => {
          this.listaTransacoes = [];
          this.registrarExibicaoEventos();
      }, 2000);

      setInterval(() => {
          this.estadoLista = this.estadoLista === "undefined" ? "vazia" : "cheia"
          this.verificaExisteEventos();
          this.ref.detectChanges()
      }, 2300);
  }


  verificaExisteEventos() {
    console.log("*** verifica se existe evento");

    if (this.listaTransacoes.length > 0)  {
              this.estadoLista = "cheia";
          }
  }

async registrarExibicaoEventos() {

  this.blockchainNetworkPrefix = this.web3Service.getInfoBlockchainNetwork().blockchainNetworkPrefix;
  
  console.log("*** Executou o metodo de registrar exibicao eventos PAPEIS");

  let eventosInvestidor = await this.web3Service.recuperaEventosAdicionaInvestidor();
  console.log(eventosInvestidor);

  for (let i=0; i<eventosInvestidor.length; i++) {
    this.processaEventoInvestidor(eventosInvestidor[i])
  }
}

processaEventoInvestidor(eventoInvestidor) {
  
      let transacao: DashboardPapeis;

      transacao = {
          rbbId: eventoInvestidor.args.id,
          cnpj: "FALTA BUSCAR NO RBB REGISTRY",
          dataHora: null,
          tipo: "Investidor",
          hashID: eventoInvestidor.transactionHash,
          uniqueIdentifier: eventoInvestidor.transactionHash,
      }
          
      this.includeIfNotExists(transacao);
      this.recuperaDataHora(eventoInvestidor, transacao);

}


  async recuperaContaSelecionada() {

    let self = this;
    
    let newSelectedAccount = await this.web3Service.getCurrentAccountSync();

    if ( !self.selectedAccount || (newSelectedAccount !== self.selectedAccount && newSelectedAccount)) {

      this.selectedAccount = newSelectedAccount;
      console.log("selectedAccount=" + this.selectedAccount);
    }

  }   




  includeIfNotExists(transacao) {
    console.log("include if not exists");
    let result = this.listaTransacoes.find(tr => tr.uniqueIdentifier == transacao.uniqueIdentifier);
    if (!result) {
      this.listaTransacoes.push(transacao); 
      console.log("include" + this.listaTransacoes.length);

    }        
}


setOrder(value: string) {
    if (this.order === value) {
        this.reverse = !this.reverse;
    }
    this.order = value;
    this.ref.detectChanges();
}

customComparator(itemA, itemB) {
    return itemB - itemA;
}

async recuperaDataHora(event, transacaoPJ) {

    let timestamp = await this.web3Service.getBlockTimestamp(event.blockNumber);
    transacaoPJ.dataHora = new Date(timestamp * 1000);
    this.ref.detectChanges();
}

}
