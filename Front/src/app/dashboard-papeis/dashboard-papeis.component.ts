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
      setTimeout(() => {
          this.listaTransacoes = [];

          console.log("Zerou lista de transacoes");

          this.registrarExibicaoEventos();
      }, 1500)

      setTimeout(() => {
          this.estadoLista = this.estadoLista === "undefined" ? "vazia" : "cheia"
          this.verificaExisteEventos();
          this.ref.detectChanges()
      }, 2300)
  }


  verificaExisteEventos() {
    if (this.listaTransacoes.length >0)  {
              this.estadoLista = "cheia";
          }
  }

registrarExibicaoEventos() {

  this.blockchainNetworkPrefix = this.web3Service.getInfoBlockchainNetwork().blockchainNetworkPrefix;
  
  console.log("*** Executou o metodo de registrar exibicao eventos PAPEIS");

  let self = this;    
  this.web3Service.registraEventosAdicionaInvestidor(function (error, event) {

      if (!error) {

          let transacao: DashboardPapeis;

          console.log("Evento Papeis");
          console.log(event);
               
          transacao = {
              rbbId: event.args.id,
              cnpj: "FALTA BUSCAR NO RBB REGISTRY",
              dataHora: null,
              tipo: "Investidor",
              hashID: event.transactionHash,
              uniqueIdentifier: event.transactionHash,
          }
          
          self.includeIfNotExists(transacao);
          self.recuperaDataHora(self, event, transacao);


      } else {
          console.log("Erro no registro de eventos de papeis - investidor");
          console.log(error);
      }
    });
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
    let result = this.listaTransacoes.find(tr => tr.uniqueIdentifier == transacao.uniqueIdentifier);
    if (!result) this.listaTransacoes.push(transacao);        
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

recuperaDataHora(self, event, transacaoPJ) {
    self.web3Service.getBlockTimestamp(event.blockHash,
        function (error, result) {
            if (!error) {
                transacaoPJ.dataHora = new Date(result.timestamp * 1000);
                self.ref.detectChanges();
            }
            else {
                console.log("Erro ao recuperar data e hora do bloco");
                console.error(error);
            }
    });

}

}
