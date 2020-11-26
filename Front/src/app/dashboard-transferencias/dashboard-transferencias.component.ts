import { Component, OnInit, NgZone } from '@angular/core';
import { ChangeDetectorRef } from '@angular/core';

import { Web3Service } from './../Web3Service';
import { PessoaJuridicaService } from '../pessoa-juridica.service';
import { BnAlertsService } from 'bndes-ux4';
import { Router } from '@angular/router';


import { DashboardTransferencia } from './DashboardTransferencia';

@Component({
  selector: 'app-dashboard-transferencias',
  templateUrl: './dashboard-transferencias.component.html',
  styleUrls: ['./dashboard-transferencias.component.css']
})
export class DashboardTransferenciasComponent implements OnInit {

  public contadorLiberacao: number;
  public contadorSolicitacaoResgate: number;
  public contadorLiquidacaoResgate: number;

  public volumeLiberacao: number;
  public volumeResgate: number;
  //public volumeLiquidacaoResgate: number;
  
  public confirmedTotalSupply : number;
  public saldoBNDESToken: number;

  public tokensEmitidosDoacao: number;
  public tokensEmCirculacao: number;
  public saldoAjustesExtraordinarios: number;

  listaTransferencias: DashboardTransferencia[] = undefined;
  estadoLista: string = "undefined"

  p: number = 1;
  order: string = 'valor';
  reverse: boolean = false;

  idBNDES: number = 1;
  selectedAccount: any;  
  URLBlockchainExplorer: string;  

  constructor(private pessoaJuridicaService: PessoaJuridicaService, 
    private router: Router,
    protected bnAlertsService: BnAlertsService, private web3Service: Web3Service,
    private ref: ChangeDetectorRef, private zone: NgZone) {

      let self = this;
      self.recuperaContaSelecionada();
      
      setInterval(function () {
        self.recuperaContaSelecionada(), 
        1000}); 

    }

  ngOnInit() {

    this.contadorLiberacao = 0;
    this.contadorSolicitacaoResgate = 0;
    this.contadorLiquidacaoResgate = 0;

    this.volumeLiberacao = 0;
    this.volumeResgate = 0;

    this.confirmedTotalSupply = 0;
    this.tokensEmitidosDoacao = 0;
    this.tokensEmCirculacao = 0;
    this.saldoAjustesExtraordinarios = 0;

    this.listaTransferencias = [];


    setTimeout(() => {
      this.registrarExibicaoEventos();
    }, 1500)

    setTimeout(() => {
      this.estadoLista = this.estadoLista === "undefined" ? "vazia" : "cheia"
      this.ref.detectChanges()
    }, 2300)

    setInterval(() => {
      this.verificaExisteEventos();
      this.getConfirmedTotalSupply();
      this.recuperaSaldoBNDESToken();
    }, 1000)

  }

  verificaExisteEventos() {
    console.log("*** verifica se existe evento");

    if (this.listaTransferencias.length > 0)  {
              this.estadoLista = "cheia";
          }
  }  

  async recuperaContaSelecionada() {

    let self = this;
    
    let newSelectedAccount = await this.web3Service.getCurrentAccountSync();

    if ( !self.selectedAccount || (newSelectedAccount !== self.selectedAccount && newSelectedAccount)) {

      this.selectedAccount = newSelectedAccount;
      console.log("selectedAccount=" + this.selectedAccount);
    }

  }    


  routeToLiquidacaoResgate(solicitacaoResgateId) {
    this.router.navigate(['bndes/liquidar/' + solicitacaoResgateId]);

  }  

  getConfirmedTotalSupply() {
    let self = this;
    return -1;
    //TODO: implementar, precisa alterar o smart contract para manter o total supply
/*
    this.web3Service.getConfirmedTotalSupply(

      function (result) {
        console.log("getConfirmedTotalSupply eh " + result);
        self.confirmedTotalSupply = result;
        self.calculaSaldos();
        self.ref.detectChanges();
      },
      function (error) {
        console.log("Erro ao ler getConfirmedTotalSupply ");
        console.log(error);
      });
*/
  }

  calculaSaldos() {
    this.tokensEmitidosDoacao = this.volumeResgate+this.confirmedTotalSupply;
    this.tokensEmCirculacao = this.confirmedTotalSupply - this.saldoBNDESToken;
    this.saldoAjustesExtraordinarios = (this.confirmedTotalSupply + this.volumeResgate) - (this.saldoBNDESToken + this.volumeLiberacao);
  }

  async recuperaSaldoBNDESToken() {

    let self = this;
  /* TODO
    this.web3Service.getDisbursementBalance(
      function (result) {
        console.log("Saldo eh " + result);
        self.saldoBNDESToken = result;
        self.calculaSaldos();
        self.ref.detectChanges();
      },
      function (error) {
        console.log("Erro ao ler o saldo do BNDES ");
        console.log(error);
        self.saldoBNDESToken = 0;
      });
      */
  }  

  registrarExibicaoEventos() {

    console.log("registrarExibicaoEventos");

    this.URLBlockchainExplorer = this.web3Service.getInfoBlockchain().URLBlockchainExplorer;

    let self = this;

    this.web3Service.recuperaEventosAlocacaoParaDesembolso().then(function(eventos) {
      console.log(eventos);
      eventos.forEach(self.processaEventoAlocacaoParaDesembolso, self); 
    });

    this.web3Service.recuperaEventosAlocacaoParaContaAdm().then(function(eventos) {
      console.log(eventos);
      eventos.forEach(self.processaEventoAlocacaoParaContaAdm, self); 
    });

    this.web3Service.recuperaEventosLiberacao().then(function(eventos) {
      console.log(eventos);
      eventos.forEach(self.processaEventoLiberacao, self); 
    });      

    this.web3Service.recuperaEventosPagamentoFornecedores().then(function(eventos) {
      console.log(eventos);
      eventos.forEach(self.processaEventoPagamentoFornecedores, self); 
    });      

    this.web3Service.recuperaEventosBNDESPagaFornecedores().then(function(eventos) {
      console.log(eventos);
      eventos.forEach(self.processaEventoPagamentoBNDESFornecedores, self); 
    });      

    this.web3Service.recuperaEventosResgate().then(function(eventos) {
      console.log(eventos);
      eventos.forEach(self.processaEventoResgate, self); 
    });      

    
    // EVENTOS LIBERAÇÃO
//    this.registrarExibicaoEventosLiberacao()

    // EVENTOS SOLICITACAO DE RESGATE
//    this.registrarExibicaoEventosSolicitacaoResgate()

//    console.log("antes de atualizar - contador liberacao " + self.contadorLiberacao);
//    console.log("antes de atualizar - contador liquidacao resgate " + self.contadorLiquidacaoResgate);
//    console.log("antes de atualizar - contador solicitacao resgate " + self.contadorSolicitacaoResgate);

//    console.log("antes de atualizar - volume liberacao " + self.volumeLiberacao);
//    console.log("antes de atualizar - volume resgate " + self.volumeResgate);

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

  processaEventoAlocacaoParaDesembolso(evento) {
    
    let transacao: DashboardTransferencia;
    
    transacao = {
        deId: this.idBNDES,
        deRazaoSocial: "Erro: Não encontrado",
        deCnpj: "FALTA BUSCAR " + this.idBNDES,
        deConta: "0",
        paraId: this.idBNDES,
        paraRazaoSocial: "Erro: Não encontrado",
        paraCnpj: "FALTA BUSCAR " + this.idBNDES,
        paraConta: "0",
        valor: this.web3Service.converteInteiroParaDecimal(parseInt(evento.args.amount)),
        tipo: "Alocação Desembolso",
        hashID: evento.transactionHash,
        dataHora: null

    }

    this.includeIfNotExists(transacao);
    this.recuperaDataHora(evento, transacao); 

  }

  processaEventoAlocacaoParaContaAdm(evento) {
    
    let transacao: DashboardTransferencia;
    
    transacao = {
        deId: this.idBNDES,
        deRazaoSocial: "Erro: Não encontrado " + this.idBNDES,
        deCnpj: "FALTA BUSCAR",
        deConta: "0",
        paraId: this.idBNDES,
        paraRazaoSocial: "Erro: Não encontrado " + this.idBNDES,
        paraCnpj: "FALTA BUSCAR",
        paraConta: "0",
        valor: this.web3Service.converteInteiroParaDecimal(parseInt(evento.args.amount)),
        tipo: "Alocação Adm",
        hashID: evento.transactionHash,
        dataHora: null

    }

    this.includeIfNotExists(transacao);
    this.recuperaDataHora(evento, transacao); 

  }


  processaEventoLiberacao(evento) {

    let transacao: DashboardTransferencia;
    
    transacao = {
        deId: this.idBNDES,
        deRazaoSocial: "Erro: Não encontrado",
        deCnpj: "FALTA BUSCAR " + this.idBNDES,
        deConta: "0",
        paraId: evento.args.idClient,
        paraRazaoSocial: "Erro: Não encontrado",
        paraCnpj: "FALTA BUSCAR " + evento.args.idClient,
        paraConta: evento.args.idFinancialSupportAgreement,
        valor: this.web3Service.converteInteiroParaDecimal(parseInt(evento.args.amount)),
        tipo: "Liberacao",
        hashID: evento.transactionHash,
        dataHora: null

    }

    this.includeIfNotExists(transacao);
    this.recuperaDataHora(evento, transacao);

  }   

 // ???
  processaEventoPagamentoFornecedores(evento) {
    let transacao: DashboardTransferencia;
    
    transacao = {
      deId: evento.args.fromId,
      deRazaoSocial: "Erro: Não encontrado",
      deCnpj: "FALTA BUSCAR " + evento.args.fromId,
      deConta: evento.args.idFinancialSupportAgreement,
      paraId: evento.args.toId,
      paraRazaoSocial: "Erro: Não encontrado",
      paraCnpj: "FALTA BUSCAR " + evento.args.toId,
      paraConta: "0",
      valor: this.web3Service.converteInteiroParaDecimal(parseInt(evento.args.amount)),
      tipo: "Pagamento",
      hashID: evento.transactionHash,
      dataHora: null
    }
    this.includeIfNotExists(transacao);
    this.recuperaDataHora(evento, transacao);

  }

  processaEventoPagamentoBNDESFornecedores(evento) {
    let transacao: DashboardTransferencia;
    
    transacao = {
      deId: this.idBNDES,
      deRazaoSocial: "Erro: Não encontrado",
      deCnpj: "FALTA BUSCAR " + this.idBNDES,
      deConta: "0",
      paraId: evento.args.toId,
      paraRazaoSocial: "Erro: Não encontrado",
      paraCnpj: "FALTA BUSCAR " + evento.args.toId,
      paraConta: "0",
      valor: this.web3Service.converteInteiroParaDecimal(parseInt(evento.args.amount)),
      tipo: "Pagamento BNDES",
      hashID: evento.transactionHash,
      dataHora: null
    }
    this.includeIfNotExists(transacao);
    this.recuperaDataHora(evento, transacao);

  }

  processaEventoResgate(evento) {
    let transacao: DashboardTransferencia;
    
    transacao = {
      deId: evento.args.idClaimer,
      deRazaoSocial: "Erro: Não encontrado",
      deCnpj: "FALTA BUSCAR " + evento.args.idClaimer,
      deConta: "0",
      paraId: 0,
      paraRazaoSocial: "N/A",
      paraCnpj: "N/A",
      paraConta: "0",
      valor: this.web3Service.converteInteiroParaDecimal(parseInt(evento.args.amount)),
      tipo: "Solicitação de Resgate",
      hashID: evento.transactionHash,
      dataHora: null
    }
    this.includeIfNotExists(transacao);
    this.recuperaDataHora(evento, transacao);

  }





  registrarExibicaoEventosLiberacao() {
    let self = this

    console.log("registraEventosLiberacao antes callback");

/*
    this.web3Service.registraEventosLiberacao(function (event) {

      console.log("registraEventosLiberacao");

        let liberacao: DashboardTransferencia;
        let eventoLiberacao = event;

        self.pessoaJuridicaService.recuperaEmpresaPorCnpj(eventoLiberacao.args.cnpj).subscribe(
          data => {

            liberacao = {
              deRazaoSocial: self.razaoSocialBNDES,
              deCnpj: "BNDES",
              deConta: "0",
              paraRazaoSocial: "Erro: Não encontrado",
              paraCnpj: eventoLiberacao.args.cnpj,
              paraConta: eventoLiberacao.args.idFinancialSupportAgreement,
              valor: self.web3Service.converteInteiroParaDecimal(parseInt(eventoLiberacao.args.amount)),
              tipo: "Liberação",
              hashID: eventoLiberacao.transactionHash,
              dataHora: null
            };

            if (data && data.dadosCadastrais) {
              liberacao.paraRazaoSocial = data.dadosCadastrais.razaoSocial;
            }

            // Colocar dentro da zona do Angular para ter a atualização de forma correta
            self.zone.run(() => {
              self.estadoLista = "cheia";
              let incluiu = self.includeIfNotExists(liberacao);              
              if (incluiu) {

                self.contadorLiberacao++;
                self.volumeLiberacao += self.web3Service.converteInteiroParaDecimal(parseInt(eventoLiberacao.args.amount));

                console.log("inseriu liberacao " + liberacao.hashID);
                console.log("contador liberacao " + self.contadorLiberacao);
                console.log("volume liberacao " + self.volumeLiberacao);    
              }
            });

              self.recuperaDataHora(eventoLiberacao, liberacao);

              console.log("Chegou no final da função");
          },
          error => {
            console.log("Erro ao recuperar empresa por CNPJ do evento liberação")
          }
        )

    });
    */
  }

  async recuperaDataHora(event, transacaoPJ) {

    let timestamp = await this.web3Service.getBlockTimestamp(event.blockNumber);
    transacaoPJ.dataHora = new Date(timestamp * 1000);
    this.ref.detectChanges();
}


  includeIfNotExists(transacaoPJ) {
    let result = this.listaTransferencias.find(tr => tr.hashID == transacaoPJ.hashID);
    if (!result) {
        this.listaTransferencias.push(transacaoPJ);
        return true;
      }
    return (false);        
 } 
 



 
} 