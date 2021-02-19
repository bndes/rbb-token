import { PessoaJuridicaService } from '../pessoa-juridica.service';
import { BnAlertsService } from 'bndes-ux4';
import { Utils } from '../shared/utils';
import { Injectable } from '@angular/core';

@Injectable()
export class PessoaJuridicaHandle  {
  cnpj: string="";
  razaoSocial: string="";
  

  constructor(private pessoaJuridicaService: PessoaJuridicaService,protected bnAlertsService: BnAlertsService) { 
    
  }

 

  
  recuperaClientePorCNPJ() {
    console.log(this.cnpj);

    this.pessoaJuridicaService.recuperaEmpresaPorCnpj(this.cnpj).subscribe(
      empresa => {
        if (empresa && empresa.dadosCadastrais) {
          console.log("empresa encontrada abaixo ");
          console.log(empresa);

          this.razaoSocial = empresa.dadosCadastrais.razaoSocial;
        }
        else {
          let texto = "Nenhuma empresa encontrada com o cnpj " + this.cnpj;
          console.log(texto);
          Utils.criarAlertaAcaoUsuario( this.bnAlertsService, texto);

        }
      },
      error => {
        let texto = "Erro ao buscar dados da empresa";
        console.log(texto);
        Utils.criarAlertaErro( this.bnAlertsService, texto,error);
      });

  }
  

  
}

