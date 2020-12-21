import { Component, OnInit, NgZone } from '@angular/core';
import { ChangeDetectorRef } from '@angular/core';
import { Router } from '@angular/router';

import { Resgate } from './Resgate';

import { Web3Service } from './../Web3Service';
import { PessoaJuridicaService } from '../pessoa-juridica.service';

import { BnAlertsService } from 'bndes-ux4';
import { Utils } from '../shared/utils';

@Component({
  selector: 'app-resgate',
  templateUrl: './resgate.component.html',
  styleUrls: ['./resgate.component.css']
})
export class ResgateComponent implements OnInit {

  resgate: Resgate = new Resgate();

  maskCnpj: any;  
  selectedAccount: any;    

  constructor(private pessoaJuridicaService: PessoaJuridicaService, protected bnAlertsService: BnAlertsService, private web3Service: Web3Service,
    private ref: ChangeDetectorRef, private zone: NgZone, private router: Router) {

      let self = this;
      setInterval(function () {
        self.recuperaContaSelecionada(), 1000});
  }

  ngOnInit() {
    this.maskCnpj = Utils.getMaskCnpj();     

  }

  inicializaResgate() {
    this.resgate.razaoSocialOrigem = "";
    this.resgate.cnpjOrigem = "";
    this.resgate.saldoOrigem = undefined;
    this.resgate.valor = 0;

  }

  async recuperaContaSelecionada() {

    let self = this;

    let newSelectedAccount = await this.web3Service.getCurrentAccountSync();
  
    if ( !self.selectedAccount || (newSelectedAccount !== self.selectedAccount && newSelectedAccount)) {
  
      self.selectedAccount = newSelectedAccount;
      console.log("selectedAccount=" + self.selectedAccount);
      this.resgate.contaBlockchainOrigem = newSelectedAccount+"";
      
      
      this.recuperaInformacoesDerivadasConta();
      
      
    }
  } 


async recuperaInformacoesDerivadasConta() {

  let self = this;

  let contaBlockchain = this.resgate.contaBlockchainOrigem.toLowerCase();

  console.log("ContaBlockchain = " + contaBlockchain);

  if ( contaBlockchain != undefined && contaBlockchain != "" && contaBlockchain.length == 42 ) {

    let registryOrigem =  await this.web3Service.getRegistryByAddressSync(this.resgate.contaBlockchainOrigem);
    console.log("registry = " );
    console.log(registryOrigem);

    let cnpjContaOrigem = registryOrigem["cnpj"];

    if ( cnpjContaOrigem != "") { //encontrou uma PJ valida
         
            console.log(cnpjContaOrigem);
            self.resgate.cnpjOrigem = cnpjContaOrigem;

            let supplierId = <number> (await this.web3Service.getRBBIDByCNPJSync(parseInt(this.resgate.cnpjOrigem)));
            if (!(await this.web3Service.isSupplier(supplierId))) {
              let s = "CNPJ não é um fornecedor.";
              this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
      
             }  
            this.pessoaJuridicaService.recuperaEmpresaPorCnpj(self.resgate.cnpjOrigem).subscribe(
              data => {
                  if (data && data.dadosCadastrais) {
                  self.resgate.razaoSocialOrigem = data.dadosCadastrais.razaoSocial;
              }
              else {
                let texto = "Nenhuma empresa encontrada associada ao CNPJ";
                console.log(texto);
                Utils.criarAlertaAcaoUsuario( this.bnAlertsService, texto);
              }
            },
            error => {
              let texto = "Erro ao buscar dados da empresa";
              console.log(texto);
              Utils.criarAlertaErro( this.bnAlertsService, texto,error);      
              this.inicializaResgate();
            });              

            self.ref.detectChanges();

            this.recuperaSaldoOrigem(registryOrigem["id"]);


         } //fecha if de PJ valida

    else {
          let texto = "Nenhuma empresa encontrada associada a conta blockchain";
          console.log(texto);
          Utils.criarAlertaAcaoUsuario( this.bnAlertsService, texto);
          this.inicializaResgate();
    }
               
  } 
  else {
      this.inicializaResgate();
  }
}  


  async recuperaSaldoOrigem(id) {

    this.resgate.saldoOrigem = 
      await this.web3Service.getBalanceOf(id, 0);

  }


  async resgatar() {

    let self = this;
/*
//TODO: validar fornecedor
    let bCliente = await this.web3Service.isClienteSync(this.resgate.contaBlockchainOrigem);
    if (!bCliente) {
      let s = "O resgate deve ser realizado para a conta de um cliente.";
      this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
      return;
    }
*/
    let supplierId = <number> (await this.web3Service.getRBBIDByCNPJSync(parseInt(this.resgate.cnpjOrigem)));
    if (!(await this.web3Service.isSupplier(supplierId))) {
      let s = "CNPJ não é um fornecedor.";
      this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
      return;
    } 

    if ((this.resgate.valor * 1) > (Number(this.resgate.saldoOrigem) * 1)) {
      let s = "Não é possível resgatar mais do que o valor do saldo de origem.";
      this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
      console.log(s);
      return;
    }

    this.web3Service.resgata(this.resgate.valor).then(
      
        function(txHash) { 
          
          Utils.criarAlertasAvisoConfirmacao(txHash, 
            self.web3Service, 
            self.bnAlertsService, 
            "Resgate para cnpj " + self.resgate.cnpjOrigem + "  enviado. Aguarde a confirmação.", 
            "O Resgate foi confirmado na blockchain.", 
            self.zone)       
          self.router.navigate(['sociedade/dash-transf']);

        },
        function(error) {  
          Utils.criarAlertaErro( self.bnAlertsService, 
            "Erro ao resgatar na blockchain", 
            error )

        });

      Utils.criarAlertaAcaoUsuario( self.bnAlertsService, 
          "Confirme a operação no metamask e aguarde a confirmação do resgate." )         

  }

}
