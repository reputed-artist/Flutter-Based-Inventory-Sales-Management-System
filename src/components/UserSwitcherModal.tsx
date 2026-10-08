import React, { useState } from 'react';
import {
  X,
  UserCheck,
  UserPlus,
  Shield,
  Smartphone,
} from 'lucide-react';
import { useInventory } from '../context/InventoryContext';
import { OperatorUser } from '../types';
import { sound } from '../lib/sound';

export const UserSwitcherModal: React.FC = () => {
  const {
    userSwitcherModalOpen,
    setUserSwitcherModalOpen,
    operators,
    currentOperator,
    setCurrentOperator,
    addOperator,
  } = useInventory();

  const [newName, setNewName] = useState('');
  const [newRole, setNewRole] = useState<OperatorUser['role']>('Warehouse Operator');
  const [showAddForm, setShowAddForm] = useState(false);

  if (!userSwitcherModalOpen) return null;

  const handleSelect = (op: OperatorUser) => {
    setCurrentOperator(op);
    setUserSwitcherModalOpen(false);
  };

  const handleCreate = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newName.trim()) return;
    addOperator(newName, newRole);
    setNewName('');
    setShowAddForm(false);
    setUserSwitcherModalOpen(false);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4 animate-in fade-in duration-200">
      <div className="w-full max-w-sm bg-slate-900 border border-slate-700/80 rounded-2xl shadow-2xl overflow-hidden flex flex-col">
        {/* Header */}
        <div className="p-4 border-b border-slate-800 flex items-center justify-between bg-slate-900/90">
          <div className="flex items-center gap-2">
            <UserCheck className="w-5 h-5 text-blue-400" />
            <h2 className="text-sm font-bold text-slate-100">
              Active User / Device Profile
            </h2>
          </div>
          <button
            onClick={() => {
              sound.playClick();
              setUserSwitcherModalOpen(false);
            }}
            className="p-1.5 rounded-lg text-slate-400 hover:text-slate-200 hover:bg-slate-800"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Body */}
        <div className="p-4 space-y-3">
          <p className="text-xs text-slate-400">
            Select who is operating this device. All stock additions, sales, and left count adjustments will be tagged with this user in real time.
          </p>

          <div className="space-y-2">
            {operators.map(op => {
              const isSelected = currentOperator.id === op.id;

              return (
                <button
                  key={op.id}
                  type="button"
                  onClick={() => handleSelect(op)}
                  className={`w-full p-3 rounded-xl border flex items-center justify-between text-left transition active:scale-98 ${
                    isSelected
                      ? 'bg-blue-600/15 border-blue-500/50 shadow-sm'
                      : 'bg-slate-800/80 border-slate-700 hover:bg-slate-750'
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <div
                      className="w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold text-white shadow-sm"
                      style={{ backgroundColor: op.avatarColor }}
                    >
                      {op.name.charAt(0)}
                    </div>
                    <div>
                      <span className="text-xs font-bold text-slate-100 block">
                        {op.name}
                      </span>
                      <span className="text-[10px] text-slate-400">
                        {op.role}
                      </span>
                    </div>
                  </div>

                  {isSelected && (
                    <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-blue-500 text-white shadow-sm">
                      Active
                    </span>
                  )}
                </button>
              );
            })}
          </div>

          {!showAddForm ? (
            <button
              type="button"
              onClick={() => {
                sound.playClick();
                setShowAddForm(true);
              }}
              className="w-full py-2 px-3 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-medium border border-slate-700 transition flex items-center justify-center gap-1.5"
            >
              <UserPlus className="w-4 h-4 text-blue-400" />
              <span>+ Add New User / Device</span>
            </button>
          ) : (
            <form onSubmit={handleCreate} className="p-3 rounded-xl bg-slate-950 border border-slate-800 space-y-2.5">
              <span className="text-xs font-bold text-slate-200 block">
                Add Team Member
              </span>
              <div>
                <label className="block text-[10px] text-slate-400 mb-0.5">Full Name</label>
                <input
                  type="text"
                  required
                  value={newName}
                  onChange={(e) => setNewName(e.target.value)}
                  placeholder="e.g. Sarah Connor"
                  className="w-full px-2.5 py-1.5 bg-slate-800 border border-slate-700 rounded-lg text-xs text-slate-100 focus:outline-none focus:border-blue-500"
                />
              </div>
              <div>
                <label className="block text-[10px] text-slate-400 mb-0.5">Role</label>
                <select
                  value={newRole}
                  onChange={(e) => setNewRole(e.target.value as OperatorUser['role'])}
                  className="w-full px-2.5 py-1.5 bg-slate-800 border border-slate-700 rounded-lg text-xs text-slate-100 focus:outline-none focus:border-blue-500"
                >
                  <option value="Warehouse Operator">Warehouse Operator</option>
                  <option value="Sales Executive">Sales Executive</option>
                  <option value="Admin">Admin</option>
                  <option value="Technician">Technician</option>
                </select>
              </div>

              <div className="flex items-center gap-2 pt-1">
                <button
                  type="button"
                  onClick={() => setShowAddForm(false)}
                  className="flex-1 py-1.5 rounded-lg bg-slate-800 text-slate-400 text-xs hover:text-slate-200"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 py-1.5 rounded-lg bg-blue-600 hover:bg-blue-500 text-white font-semibold text-xs transition"
                >
                  Add & Select
                </button>
              </div>
            </form>
          )}
        </div>
      </div>
    </div>
  );
};
