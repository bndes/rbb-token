import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { TransferenciaAdministrativaComponent } from './transferencia-administrativa.component';

describe('TransferenciaAdministrativaComponent', () => {
  let component: TransferenciaAdministrativaComponent;
  let fixture: ComponentFixture<TransferenciaAdministrativaComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ TransferenciaAdministrativaComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(TransferenciaAdministrativaComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
