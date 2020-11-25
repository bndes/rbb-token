import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { AlocarValorAdministrativoComponent } from './alocar-valor-administrativo.component';

describe('AlocarValorAdministrativoComponent', () => {
  let component: AlocarValorAdministrativoComponent;
  let fixture: ComponentFixture<AlocarValorAdministrativoComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ AlocarValorAdministrativoComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(AlocarValorAdministrativoComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
