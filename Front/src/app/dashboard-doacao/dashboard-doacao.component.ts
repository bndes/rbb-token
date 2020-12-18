import { Component, OnInit, NgZone } from '@angular/core';
import { ChangeDetectorRef } from '@angular/core';

import { Web3Service } from './../Web3Service';
import { PessoaJuridicaService } from '../pessoa-juridica.service';
import { BnAlertsService } from 'bndes-ux4';
import { ConstantesService } from '../ConstantesService';
import { Utils } from '../shared/utils';
import {FileHandleService} from "../file-handle.service";
import {DashboardDoacao} from "./DashboardDoacao";

@Component({
  selector: 'app-dashboard-doacao',
  templateUrl: './dashboard-doacao.component.html',
  styleUrls: ['./dashboard-doacao.component.css']
})
export class DashboardDoacaoComponent implements OnInit {

  listaDoacoes: DashboardDoacao[] = undefined;

  URLBlockchainExplorer: string;

  estadoLista: string = "undefined";

  p: number = 1;
  order: string = 'dataHora';
  reverse: boolean = false;

  selectedAccount: any;

  constructor(private pessoaJuridicaService: PessoaJuridicaService, 
    private fileHandleService: FileHandleService,
    protected bnAlertsService: BnAlertsService, private web3Service: Web3Service,
    private ref: ChangeDetectorRef, private zone: NgZone) {

          let self = this;
          self.recuperaContaSelecionada();
                      
          setInterval(function () {
            self.recuperaContaSelecionada(), 
            1000}); 
            
  }

  ngOnInit() {
      setTimeout(() => {
          this.listaDoacoes = [];
          console.log("Zerou lista de investimentos");

          this.registrarExibicaoEventos();
      }, 2000)

      setInterval(() => {
          this.estadoLista = this.estadoLista === "undefined" ? "vazia" : "cheia"
          this.ref.detectChanges()
      }, 2300)
  }

  async recuperaContaSelecionada() {

      let self = this;
      
      let newSelectedAccount = await this.web3Service.getCurrentAccountSync();
  
      if ( !self.selectedAccount || (newSelectedAccount !== self.selectedAccount && newSelectedAccount)) {
  
        this.selectedAccount = newSelectedAccount;
        console.log("selectedAccount=" + this.selectedAccount);
      }
  
    }   
    
    registrarExibicaoEventos() {

      this.URLBlockchainExplorer = this.web3Service.getInfoBlockchain().URLBlockchainExplorer;

      let self = this;

      this.web3Service.recuperaEventosRegistrarInvestimento().then(function(eventos) {
        self.processaConjuntoEventos(eventos, "Intenção Registrada");
        });      

      this.web3Service.recuperaEventosRecebimentoInvestimento().then(function(eventos) {
        self.processaConjuntoEventos(eventos, "Investimento Confirmado");
        });                 

 }

  processaConjuntoEventos(eventos, tipo) {
    for (let i=0; i<eventos.length; i++) {
      this.processaEvento(eventos[i], tipo);
    }
  }
  
  async processaEvento(evento, descTipo) {

    let transacao: DashboardDoacao;
    
    transacao = {
        rbbId: evento.args.idInvestor, 
        cnpj: "FALTA RECUPERAR",
        razaoSocial: "FALTA RECUPERAR",
        valor: this.web3Service.converteInteiroParaDecimal(parseInt(evento.args.amount)),                
        dataHora: null,
        tipo: descTipo,
        hashID: evento.transactionHash,
        uniqueIdentifier: evento.transactionHash,
        hashComprovante: evento.args.docHash+"",
        filePathAndName: ""
    }

    this.includeIfNotExists(transacao);
    this.recuperaDataHora(evento, transacao);
    transacao.cnpj = await this.web3Service.getCnpjByRBBId(transacao.rbbId);
    this.recuperaInfoDerivadaPorCnpj(transacao.cnpj, transacao);

  }  

 includeIfNotExists(transacao) {
    let result = this.listaDoacoes.find(tr => tr.uniqueIdentifier == transacao.uniqueIdentifier);
    if (!result) this.listaDoacoes.push(transacao);        
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

async recuperaInfoDerivadaPorCnpj(cnpj, transacao) {

  transacao.razacaoSocial = "Erro: Não encontrado";

  let self = this;
  this.pessoaJuridicaService.recuperaEmpresaPorCnpj(cnpj).subscribe(
      data => {
          transacao.razaoSocial = "Erro: Não encontrado";
          if (data && data.dadosCadastrais) {
            transacao.razaoSocial = data.dadosCadastrais.razaoSocial;
            }
            
          // Colocar dentro da zona do Angular para ter a atualização de forma correta
          self.zone.run(() => {
              self.estadoLista = "cheia";
          });

      },
      error => {
          console.log("Erro ao buscar dados da empresa");
          transacao.razaoSocial = "";
      });
  }
  async recuperaDataHora(event, transacaoPJ) {

      let timestamp = await this.web3Service.getBlockTimestamp(event.blockNumber);
      transacaoPJ.dataHora = new Date(timestamp * 1000);
      this.ref.detectChanges();
  }


  recuperaFilePathAndName(self,transacao) {

      if ( transacao == undefined ||  (transacao.cnpj == undefined || transacao.cnpj == "" ) || ( transacao.hashComprovante == undefined || transacao.hashComprovante == "") ) {
          console.log("Transacao incompleta no recuperaFilePathAndName do dashboard-doacao");
          return;
      }

      self.fileHandleService.buscaFileInfo(transacao.cnpj, "0", "0", transacao.hashComprovante, "comp_doacao").subscribe(
          result => {
            if (result && result.pathAndName) {
              transacao.filePathAndName=ConstantesService.serverUrlRoot+result.pathAndName;
            }
            else {
              let texto = "Não foi possível encontrar informações associadas ao arquivo.";
              console.log(texto);
              Utils.criarAlertaAcaoUsuario( self.bnAlertsService, texto);       
            }                  
          }, 
          error => {
            let texto = "Erro ao buscar dados de arquivo";
            console.log(texto);
            console.log("cnpj=" + transacao.cnpj);
            console.log("hashComprovante=" + transacao.hashComprovante);
  //              Utils.criarAlertaErro( self.bnAlertsService, texto,error);
          }) //fecha busca fileInfo

  }


}
