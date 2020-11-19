
import { Component, OnInit, NgZone } from '@angular/core';
import { ChangeDetectorRef } from '@angular/core';
import { Router } from '@angular/router';

import { Transferencia, Subcredito } from './Transferencia';

import { Web3Service } from './../Web3Service';
import { PessoaJuridicaService } from '../pessoa-juridica.service';

import { BnAlertsService } from 'bndes-ux4';
import { Utils } from '../shared/utils';

@Component({
  selector: 'app-realizar-pagamento',
  templateUrl: './realizar-pagamento.component.html',
  styleUrls: ['./realizar-pagamento.component.css']
})
export class RealizarPagamentoComponent implements OnInit {

  transferencia: Transferencia;
  selectedAccount: any;
  maskCnpj: any;
  cnpjOrigem : string;

  constructor(private pessoaJuridicaService: PessoaJuridicaService, protected bnAlertsService: BnAlertsService, private web3Service: Web3Service,
    private ref: ChangeDetectorRef, private zone: NgZone, private router: Router) {

      let self = this;
      setInterval(function () {
        self.recuperaContaSelecionada(), 1000});

  }

  ngOnInit() {
    this.maskCnpj = Utils.getMaskCnpj();      
    this.transferencia = new Transferencia();
    this.inicializaDadosOrigem();
    this.inicializaDadosDestino();

  }


  inicializaDadosOrigem() {
    this.transferencia.subcreditos = new Array<Subcredito>();    
    this.transferencia.numeroSubcreditoSelecionado = null;
    this.transferencia.saldoOrigem = undefined;    
  }


  inicializaDadosDestino() {

    this.transferencia.cnpjDestino = "";
    this.transferencia.razaoSocialDestino = "";
    this.transferencia.msgEmpresaDestino = "";
  }

  async recuperaContaSelecionada() {

    let self = this;
    
    let newSelectedAccount = await this.web3Service.getCurrentAccountSync();
  
    if ( !self.selectedAccount || (newSelectedAccount !== self.selectedAccount && newSelectedAccount)) {
  
      self.selectedAccount = newSelectedAccount;
      console.log("selectedAccount=" + this.selectedAccount);
      this.transferencia.contaBlockchainOrigem = newSelectedAccount+"";

      this.recuperaEmpresaOrigemPorContaBlockchain(this.transferencia.contaBlockchainOrigem);
      this.ref.detectChanges();
        
    }
  
  }  
  
  async recuperaEmpresaOrigemPorContaBlockchain(contaBlockchain) {

    let self = this;

    contaBlockchain = contaBlockchain.toLowerCase();   

    if ( contaBlockchain != undefined && contaBlockchain != "" && contaBlockchain.length == 42 ) {

      let cnpjConta = <string> (await this.web3Service.getCNPJByAddressSync(contaBlockchain));      
      await this.recuperaClientePorCNPJ(cnpjConta);
    }
}


async recuperaClientePorCNPJ(cnpj) {
  console.log(cnpj);

  let self = this;

  let rbbID = <number> (await this.web3Service.getRBBIDByCNPJSync(parseInt(cnpj)));

  if (!rbbID) {
    let s = "CNPJ não está cadastrado.";
    this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
    return;
  } 
  this.transferencia.rbbId = rbbID; 

  this.pessoaJuridicaService.recuperaClientePorCnpj(cnpj).subscribe(
    empresa => {
      if (empresa && empresa.dadosCadastrais) {
        console.log("empresa encontrada abaixo ");
        console.log(empresa);

        if (empresa["subcreditos"] && empresa["subcreditos"].length>0) {

          for (var i = 0; i < empresa["subcreditos"].length; i++) {
          
            let subStr = JSON.parse(JSON.stringify(empresa["subcreditos"][i]));

            self.includeIfNotExists(self.transferencia.subcreditos, subStr);

            //TODO: otimizar para fazer isso apenas uma vez
            if (i==0) {
              self.transferencia.numeroSubcreditoSelecionado = self.transferencia.subcreditos[0].numero;
              self.atualizaInfoPorMudancaSubcredito();
            }
          }
             
        }
        else {
          let s = "O pagamento só pode ser realizado por uma empresa cliente.";
          this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
          console.log(s);
        }
      }
      else {
        let texto = "Nenhuma empresa cliente encontrada com o cnpj " + cnpj;
        console.log(texto);
        Utils.criarAlertaAcaoUsuario( this.bnAlertsService, texto);

        this.inicializaDadosOrigem();
      }
    },
    error => {
      let texto = "Erro ao buscar dados da empresa";
      console.log(texto);
      Utils.criarAlertaErro( this.bnAlertsService, texto,error);
      this.inicializaDadosOrigem();
    });

}

includeIfNotExists(subcreditos, sub) {

  let include = true;
  for(var i=0; i < subcreditos.length; i++) { 
    if (subcreditos[i].numero==sub.numero) {
      include=false;
    }
  }  
  if (include) subcreditos.push(sub);
}


async atualizaInfoPorMudancaSubcredito() {

  console.log("atualiza rbbId=" + this.transferencia.rbbId + " nSubc = " + this.transferencia.numeroSubcreditoSelecionado);

  this.transferencia.saldoOrigem = 
    await this.web3Service.getBalanceOf(this.transferencia.rbbId, this.transferencia.numeroSubcreditoSelecionado);

  console.log(this.transferencia.saldoOrigem);

}


  async recuperaInformacoesDerivadasConta() {

    let self = this;

    let contaBlockchain = this.transferencia.contaBlockchainDestino.toLowerCase();

    console.log("ContaBlockchain" + contaBlockchain);

    if ( contaBlockchain != undefined && contaBlockchain != "" && contaBlockchain.length == 42 ) {

      let cnpjConta = <string> (await this.web3Service.getCNPJByAddressSync(contaBlockchain));      

            if ( cnpjConta != "" ) { //encontrou uma PJ valida  

              console.log(cnpjConta);
              self.transferencia.cnpjDestino = cnpjConta;
              if ( self.cnpjOrigem == self.transferencia.cnpjDestino) {
                let texto = "Erro: não é possível transferir entre o mesmo CNPJ: " + self.cnpjOrigem;
                console.log(texto);
                Utils.criarAlertaErro( this.bnAlertsService, texto, null);       

                this.inicializaDadosDestino();                
              } 
              else { 
                this.pessoaJuridicaService.recuperaEmpresaPorCnpj(self.transferencia.cnpjDestino).subscribe(
                  data => {
                      if (data && data.dadosCadastrais) {
                      console.log("RECUPERA EMPRESA DESTINO")
                      console.log(data)
                      self.transferencia.razaoSocialDestino = data.dadosCadastrais.razaoSocial;
//                      this.validaEmpresaDestino(contaBlockchain);
                  }
                  else {
                    let texto = "Nenhuma empresa encontrada associada ao CNPJ";
                    console.log(texto);
                    Utils.criarAlertaAcaoUsuario( this.bnAlertsService, texto);       
                    //this.inicializaDadosDestino();
                    this.transferencia.msgEmpresaDestino = "Conta Inválida"
                  }
                },
                  error => {
                      let texto = "Erro ao buscar dados da empresa";
                      console.log(texto);
                      Utils.criarAlertaErro( this.bnAlertsService, texto,error);       
                      this.inicializaDadosDestino();
                  });              
              }
              self.ref.detectChanges();

           } //fecha if de PJ valida

           else {
            let texto = "Nenhuma empresa encontrada associada a conta blockchain";
            console.log(texto);
            Utils.criarAlertaAcaoUsuario( this.bnAlertsService, texto);       
            this.inicializaDadosDestino();
            this.transferencia.msgEmpresaDestino = "Conta Inválida"

             console.log("Não encontrou PJ valida para a conta blockchain");
           }
                 
    } 
    else {
        this.inicializaDadosDestino();
    }
}


  validaEmpresaDestino(contaBlockchainDestino) {

    /*
    let self = this

    self.web3Service.isFornecedor(contaBlockchainDestino,
      (result) => {
        if (result) {
          self.transferencia.msgEmpresaDestino = "Fornecedor"
        } else {
          console.log("Conta Invalida")
          self.transferencia.msgEmpresaDestino = "Conta Inválida"
        }
        self.ref.detectChanges()
      },
      (erro) => {
        console.log(erro)
        self.transferencia.msgEmpresaDestino = ""
      })  
      */
  }


  async transferir() {
/*
    let self = this;

    let bClienteOrigem = await this.web3Service.isClienteSync(this.transferencia.contaBlockchainOrigem);
    if (!bClienteOrigem) {
      let s = "Conta de Origem não é de um cliente";
      this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
      return;
    }

    let bFornecedorDestino = await this.web3Service.isFornecedorSync(this.transferencia.contaBlockchainDestino);
    if (!bFornecedorDestino) {
      let s = "Conta de Destino não é de um fornecedor";
      this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
      return;
    }

    let bValidadaOrigem = await this.web3Service.isContaValidadaSync(this.transferencia.contaBlockchainOrigem);
    if (!bValidadaOrigem) {
      let s = "Conta de Origem não validada";
      this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
      return;
    }
    let bValidadaDestino = await this.web3Service.isContaValidadaSync(this.transferencia.contaBlockchainDestino);
    if (!bValidadaDestino) {
      let s = "Conta de Destino não validada";
      this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
      return;
    }

      
    //Multipliquei por 1 para a comparacao ser do valor (e nao da string)
    if ((this.transferencia.valorTransferencia * 1) > (this.transferencia.saldoOrigem * 1)) {

      console.log("saldoOrigem=" + this.transferencia.saldoOrigem);
      console.log("valorTransferencia=" + this.transferencia.valorTransferencia);

      let s = "Não é possível transferir mais do que o valor do saldo de origem.";
      this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
      return;
    }


    this.web3Service.transfer(this.transferencia.contaBlockchainDestino, this.transferencia.valorTransferencia,

        (txHash) => {
        self.transferencia.hashOperacao = txHash;
        Utils.criarAlertasAvisoConfirmacao( txHash, 
                                            self.web3Service, 
                                            self.bnAlertsService, 
                                            "Transferência para cnpj " + self.transferencia.cnpjDestino + "  enviada. Aguarde a confirmação.", 
                                            "A Transferência foi confirmada na blockchain.", 
                                            self.zone);       
        self.router.navigate(['sociedade/dash-transf']);
        
        }        
      ,(error) => {
        Utils.criarAlertaErro( self.bnAlertsService, 
                                "Erro ao transferir na blockchain", 
                                error)  
      }
    );
    Utils.criarAlertaAcaoUsuario( self.bnAlertsService, 
                                  "Confirme a operação no metamask e aguarde a confirmação da transferência." )  
    }
*/
  }

}