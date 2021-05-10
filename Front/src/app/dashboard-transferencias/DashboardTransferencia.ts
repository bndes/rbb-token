import{ PessoaJuridicaHandle} from '../PessoaJuridicaHandle/PessoaJuridicaHandle';

export class DashboardTransferencia {
  deId: number;
  deRazaoSocial: string;
  deCnpj: string;
  dePessoaJuridica:PessoaJuridicaHandle; 
  paraId: number;
  paraRazaoSocial: string;
  paraCnpj: string;
  paraPessoaJuridica:PessoaJuridicaHandle;
  deConta: string;
  paraConta: string;  
  valor: number;
  tipo: string;
  hashID: string;
  dataHora: Date;


}
